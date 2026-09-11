//go:build !windows

package app

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"crypto/sha256"
	"encoding/json"
	"errors"
	"io"
	"os"
	"path/filepath"
)

func encryptedCredentialPath() string { return filepath.Join(configDir(), "credentials.enc") }
func credentialKey() ([]byte, error) {
	raw := os.Getenv("KAIROS_CREDENTIAL_KEY")
	if len(raw) < 16 {
		return nil, errors.New("KAIROS_CREDENTIAL_KEY must contain at least 16 characters")
	}
	sum := sha256.Sum256([]byte(raw))
	return sum[:], nil
}
func credentialAEAD() (cipher.AEAD, error) {
	key, err := credentialKey()
	if err != nil {
		return nil, err
	}
	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, err
	}
	return cipher.NewGCM(block)
}

func loadAllCredentials() (map[string]Credentials, error) {
	data, err := os.ReadFile(encryptedCredentialPath())
	if errors.Is(err, os.ErrNotExist) {
		return map[string]Credentials{}, nil
	}
	if err != nil {
		return nil, err
	}
	aead, err := credentialAEAD()
	if err != nil {
		return nil, err
	}
	if len(data) < aead.NonceSize() {
		return nil, errors.New("invalid encrypted credential file")
	}
	plain, err := aead.Open(nil, data[:aead.NonceSize()], data[aead.NonceSize():], nil)
	if err != nil {
		return nil, errors.New("cannot decrypt credential file")
	}
	all := map[string]Credentials{}
	if err := json.Unmarshal(plain, &all); err != nil {
		return nil, err
	}
	return all, nil
}

func LoadCredentials(server string) (Credentials, error) {
	all, err := loadAllCredentials()
	if err != nil {
		return Credentials{}, err
	}
	return all[server], nil
}

func SaveCredentials(server string, value Credentials, allowEncryptedFile bool) error {
	if !allowEncryptedFile {
		return errors.New("no OS keychain available; pass --allow-encrypted-file and set KAIROS_CREDENTIAL_KEY")
	}
	all, err := loadAllCredentials()
	if err != nil {
		return err
	}
	all[server] = value
	plain, err := json.Marshal(all)
	if err != nil {
		return err
	}
	aead, err := credentialAEAD()
	if err != nil {
		return err
	}
	nonce := make([]byte, aead.NonceSize())
	if _, err := io.ReadFull(rand.Reader, nonce); err != nil {
		return err
	}
	encrypted := aead.Seal(nonce, nonce, plain, nil)
	if err := os.MkdirAll(configDir(), 0o700); err != nil {
		return err
	}
	return os.WriteFile(encryptedCredentialPath(), encrypted, 0o600)
}

func DeleteCredentials(server string) error {
	if _, statErr := os.Stat(encryptedCredentialPath()); errors.Is(statErr, os.ErrNotExist) {
		return nil
	}
	all, err := loadAllCredentials()
	if errors.Is(err, os.ErrNotExist) {
		return nil
	}
	if err != nil {
		return err
	}
	delete(all, server)
	if len(all) == 0 {
		return os.Remove(encryptedCredentialPath())
	}
	encoded, err := json.Marshal(all)
	if err != nil {
		return err
	}
	aead, err := credentialAEAD()
	if err != nil {
		return err
	}
	nonce := make([]byte, aead.NonceSize())
	if _, err := io.ReadFull(rand.Reader, nonce); err != nil {
		return err
	}
	encrypted := aead.Seal(nonce, nonce, encoded, nil)
	return os.WriteFile(encryptedCredentialPath(), encrypted, 0o600)
}
