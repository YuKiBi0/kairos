//go:build windows

package app

import (
	"encoding/json"
	"errors"
	"fmt"
	"syscall"
	"unsafe"
)

const (
	credTypeGeneric         = 1
	credPersistLocalMachine = 2
	errorNotFound           = syscall.Errno(1168)
)

type credentialW struct {
	Flags, Type             uint32
	TargetName, Comment     *uint16
	LastWritten             syscall.Filetime
	CredentialBlobSize      uint32
	CredentialBlob          *byte
	Persist, AttributeCount uint32
	Attributes              uintptr
	TargetAlias, UserName   *uint16
}

var (
	advapi32    = syscall.NewLazyDLL("advapi32.dll")
	credWriteW  = advapi32.NewProc("CredWriteW")
	credReadW   = advapi32.NewProc("CredReadW")
	credDeleteW = advapi32.NewProc("CredDeleteW")
	credFree    = advapi32.NewProc("CredFree")
)

func credentialTarget(server string) string { return "Kairos CLI/" + server }

func LoadCredentials(server string) (Credentials, error) {
	target, err := syscall.UTF16PtrFromString(credentialTarget(server))
	if err != nil {
		return Credentials{}, err
	}
	var raw *credentialW
	ok, _, callErr := credReadW.Call(uintptr(unsafe.Pointer(target)), credTypeGeneric, 0, uintptr(unsafe.Pointer(&raw)))
	if ok == 0 {
		if errors.Is(callErr, errorNotFound) {
			return Credentials{}, nil
		}
		return Credentials{}, fmt.Errorf("read Windows Credential Manager: %w", callErr)
	}
	defer credFree.Call(uintptr(unsafe.Pointer(raw)))
	data := unsafe.Slice(raw.CredentialBlob, int(raw.CredentialBlobSize))
	var value Credentials
	if err := json.Unmarshal(data, &value); err != nil {
		return Credentials{}, err
	}
	return value, nil
}

func SaveCredentials(server string, value Credentials, _ bool) error {
	data, err := json.Marshal(value)
	if err != nil {
		return err
	}
	if len(data) > 2560 {
		return errors.New("credential payload is too large")
	}
	target, err := syscall.UTF16PtrFromString(credentialTarget(server))
	if err != nil {
		return err
	}
	username, _ := syscall.UTF16PtrFromString("kairos-cli")
	credential := credentialW{Type: credTypeGeneric, TargetName: target, CredentialBlobSize: uint32(len(data)), CredentialBlob: &data[0], Persist: credPersistLocalMachine, UserName: username}
	ok, _, callErr := credWriteW.Call(uintptr(unsafe.Pointer(&credential)), 0)
	if ok == 0 {
		return fmt.Errorf("write Windows Credential Manager: %w", callErr)
	}
	return nil
}

func DeleteCredentials(server string) error {
	target, err := syscall.UTF16PtrFromString(credentialTarget(server))
	if err != nil {
		return err
	}
	ok, _, callErr := credDeleteW.Call(uintptr(unsafe.Pointer(target)), credTypeGeneric, 0)
	if ok == 0 && !errors.Is(callErr, errorNotFound) {
		return fmt.Errorf("delete Windows Credential Manager credential: %w", callErr)
	}
	return nil
}
