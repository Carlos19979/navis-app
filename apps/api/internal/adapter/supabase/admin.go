package supabase

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"time"
)

// listPageSize is the Storage list page size; pages are fetched until a short
// page is returned so no object is left behind.
const listPageSize = 1000

// Admin implements port.SupabaseAdmin using the Supabase Storage and GoTrue
// admin REST APIs, authenticated with the service role key.
type Admin struct {
	baseURL    string
	serviceKey string
	http       *http.Client
	logger     *slog.Logger
}

// NewAdmin creates a new Admin client. baseURL is the project URL
// (e.g. https://xyz.supabase.co). An empty serviceKey leaves the client in a
// disabled state where every call fails loudly — config.Validate prevents this
// in production.
func NewAdmin(baseURL, serviceKey string, logger *slog.Logger) *Admin {
	return &Admin{
		baseURL:    baseURL,
		serviceKey: serviceKey,
		http:       &http.Client{Timeout: 30 * time.Second},
		logger:     logger,
	}
}

// storageObject is one entry of a Storage list response. Folders are virtual
// and carry a null id; files have a non-null id.
type storageObject struct {
	ID   *string `json:"id"`
	Name string  `json:"name"`
}

// DeleteUserFiles removes every object under "<userID>/" in the given bucket,
// recursing into subfolders (uploads use nested paths like userID/boatID/...).
func (a *Admin) DeleteUserFiles(ctx context.Context, bucket, userID string) error {
	if a.serviceKey == "" {
		return fmt.Errorf("supabase admin: SUPABASE_SERVICE_ROLE_KEY not configured")
	}
	return a.deleteFolder(ctx, bucket, userID)
}

// deleteFolder deletes all files directly under path, recurses into
// subfolders, and re-lists until the folder is empty. Virtual folders vanish
// once their last file is removed, so the loop always makes progress.
func (a *Admin) deleteFolder(ctx context.Context, bucket, path string) error {
	for {
		objects, err := a.listObjects(ctx, bucket, path)
		if err != nil {
			return err
		}
		if len(objects) == 0 {
			return nil
		}

		var files []string
		for _, o := range objects {
			if o.ID == nil {
				if err := a.deleteFolder(ctx, bucket, path+"/"+o.Name); err != nil {
					return err
				}
				continue
			}
			files = append(files, path+"/"+o.Name)
		}

		if len(files) > 0 {
			if err := a.deleteObjects(ctx, bucket, files); err != nil {
				return err
			}
			a.logger.Info("supabase admin: deleted storage objects",
				slog.String("bucket", bucket),
				slog.String("folder", path),
				slog.Int("count", len(files)))
		}

		if len(objects) < listPageSize {
			return nil
		}
	}
}

// DeleteAuthUser removes the user from auth.users via the GoTrue admin API.
// The ON DELETE CASCADE foreign keys on every app table remove the user's rows
// atomically. A 404 is treated as success (already deleted).
func (a *Admin) DeleteAuthUser(ctx context.Context, userID string) error {
	if a.serviceKey == "" {
		return fmt.Errorf("supabase admin: SUPABASE_SERVICE_ROLE_KEY not configured")
	}

	url := fmt.Sprintf("%s/auth/v1/admin/users/%s", a.baseURL, userID)
	req, err := http.NewRequestWithContext(ctx, http.MethodDelete, url, nil)
	if err != nil {
		return fmt.Errorf("supabase admin: create request: %w", err)
	}
	a.setAuth(req)

	resp, err := a.http.Do(req)
	if err != nil {
		return fmt.Errorf("supabase admin: delete auth user: %w", err)
	}
	defer func() { _ = resp.Body.Close() }()

	if resp.StatusCode >= 400 && resp.StatusCode != http.StatusNotFound {
		return fmt.Errorf("supabase admin: delete auth user: status %d", resp.StatusCode)
	}
	return nil
}

// listObjects returns one page of objects directly under "<prefix>/" in bucket.
func (a *Admin) listObjects(ctx context.Context, bucket, prefix string) ([]storageObject, error) {
	body, err := json.Marshal(map[string]any{
		"prefix": prefix,
		"limit":  listPageSize,
		"offset": 0,
	})
	if err != nil {
		return nil, fmt.Errorf("supabase admin: marshal list body: %w", err)
	}

	url := fmt.Sprintf("%s/storage/v1/object/list/%s", a.baseURL, bucket)
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		return nil, fmt.Errorf("supabase admin: create request: %w", err)
	}
	a.setAuth(req)
	req.Header.Set("Content-Type", "application/json")

	resp, err := a.http.Do(req)
	if err != nil {
		return nil, fmt.Errorf("supabase admin: list objects: %w", err)
	}
	defer func() { _ = resp.Body.Close() }()

	if resp.StatusCode >= 400 {
		return nil, fmt.Errorf("supabase admin: list objects in %q: status %d", bucket, resp.StatusCode)
	}

	var objects []storageObject
	if err := json.NewDecoder(resp.Body).Decode(&objects); err != nil {
		return nil, fmt.Errorf("supabase admin: decode object list: %w", err)
	}
	return objects, nil
}

// deleteObjects removes the given object paths from a bucket.
func (a *Admin) deleteObjects(ctx context.Context, bucket string, prefixes []string) error {
	body, err := json.Marshal(map[string]any{"prefixes": prefixes})
	if err != nil {
		return fmt.Errorf("supabase admin: marshal delete body: %w", err)
	}

	url := fmt.Sprintf("%s/storage/v1/object/%s", a.baseURL, bucket)
	req, err := http.NewRequestWithContext(ctx, http.MethodDelete, url, bytes.NewReader(body))
	if err != nil {
		return fmt.Errorf("supabase admin: create request: %w", err)
	}
	a.setAuth(req)
	req.Header.Set("Content-Type", "application/json")

	resp, err := a.http.Do(req)
	if err != nil {
		return fmt.Errorf("supabase admin: delete objects: %w", err)
	}
	defer func() { _ = resp.Body.Close() }()

	if resp.StatusCode >= 400 {
		return fmt.Errorf("supabase admin: delete objects in %q: status %d", bucket, resp.StatusCode)
	}
	return nil
}

func (a *Admin) setAuth(req *http.Request) {
	req.Header.Set("Authorization", "Bearer "+a.serviceKey)
	req.Header.Set("apikey", a.serviceKey)
}
