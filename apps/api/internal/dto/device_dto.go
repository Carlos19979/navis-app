package dto

// CreateDeviceRequest is the payload for registering a push notification token.
type CreateDeviceRequest struct {
	Token    string `json:"token" validate:"required"`
	Platform string `json:"platform" validate:"required,oneof=ios android"`
}
