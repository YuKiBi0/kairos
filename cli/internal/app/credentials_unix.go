//go:build !windows

package app

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"syscall"
)

func credentialPath() string     { return filepath.Join(configDir(), "credentials.json") }
func credentialLockPath() string { return filepath.Join(configDir(), "credentials.lock") }

func withCredentialLock(lock int, action func() error) error {
	if err := os.MkdirAll(configDir(), 0o700); err != nil {
		return err
	}
	_ = os.Chmod(configDir(), 0o700)
	file, err := os.OpenFile(credentialLockPath(), os.O_CREATE|os.O_RDWR, 0o600)
	if err != nil {
		return err
	}
	defer file.Close()
	if err := syscall.Flock(int(file.Fd()), lock); err != nil {
		return err
	}
	defer func() { _ = syscall.Flock(int(file.Fd()), syscall.LOCK_UN) }()
	return action()
}

func loadAllCredentials() (map[string]Credentials, error) {
	data, err := os.ReadFile(credentialPath())
	if errors.Is(err, os.ErrNotExist) {
		return map[string]Credentials{}, nil
	}
	if err != nil {
		return nil, err
	}
	_ = os.Chmod(credentialPath(), 0o600)
	all := map[string]Credentials{}
	if err := json.Unmarshal(data, &all); err != nil {
		return nil, fmt.Errorf("invalid credential file: %w", err)
	}
	return all, nil
}

func writeAllCredentials(all map[string]Credentials) error {
	encoded, err := json.Marshal(all)
	if err != nil {
		return err
	}
	file, err := os.CreateTemp(configDir(), ".credentials-*.tmp")
	if err != nil {
		return err
	}
	temporary := file.Name()
	defer func() { _ = os.Remove(temporary) }()
	if err := file.Chmod(0o600); err != nil {
		_ = file.Close()
		return err
	}
	if _, err := file.Write(encoded); err != nil {
		_ = file.Close()
		return err
	}
	if err := file.Sync(); err != nil {
		_ = file.Close()
		return err
	}
	if err := file.Close(); err != nil {
		return err
	}
	return os.Rename(temporary, credentialPath())
}

func LoadCredentials(server string) (value Credentials, err error) {
	err = withCredentialLock(syscall.LOCK_SH, func() error {
		all, loadErr := loadAllCredentials()
		if loadErr != nil {
			return loadErr
		}
		value = all[server]
		return nil
	})
	return value, err
}

func SaveCredentials(server string, value Credentials) error {
	return withCredentialLock(syscall.LOCK_EX, func() error {
		all, err := loadAllCredentials()
		if err != nil {
			return err
		}
		all[server] = value
		return writeAllCredentials(all)
	})
}

func UpdateCredentials(server string, update func(Credentials) (Credentials, error)) (value Credentials, err error) {
	err = withCredentialLock(syscall.LOCK_EX, func() error {
		all, loadErr := loadAllCredentials()
		if loadErr != nil {
			return loadErr
		}
		current := all[server]
		value, loadErr = update(current)
		if loadErr != nil {
			return loadErr
		}
		if value == current {
			return nil
		}
		all[server] = value
		return writeAllCredentials(all)
	})
	return value, err
}

func DeleteCredentials(server string) error {
	return withCredentialLock(syscall.LOCK_EX, func() error {
		all, err := loadAllCredentials()
		if err != nil {
			return err
		}
		delete(all, server)
		if len(all) == 0 {
			if err := os.Remove(credentialPath()); err != nil && !errors.Is(err, os.ErrNotExist) {
				return err
			}
			return nil
		}
		return writeAllCredentials(all)
	})
}
