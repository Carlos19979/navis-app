package validator

import (
	"reflect"
	"strings"
)

// TrimStrings recursively trims whitespace from all string and *string fields
// in the given struct pointer.
func TrimStrings(v any) {
	val := reflect.ValueOf(v)
	if val.Kind() != reflect.Ptr || val.IsNil() {
		return
	}
	trimFields(val.Elem())
}

func trimFields(val reflect.Value) {
	if val.Kind() != reflect.Struct {
		return
	}
	for i := range val.NumField() {
		field := val.Field(i)
		if !field.CanSet() {
			continue
		}
		switch field.Kind() {
		case reflect.String:
			field.SetString(strings.TrimSpace(field.String()))
		case reflect.Ptr:
			if field.Type().Elem().Kind() == reflect.String && !field.IsNil() {
				s := strings.TrimSpace(field.Elem().String())
				field.Elem().SetString(s)
			}
		case reflect.Struct:
			trimFields(field)
		}
	}
}
