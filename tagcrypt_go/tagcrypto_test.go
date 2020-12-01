package tagcrypto_test

import (
	"encoding/json"
	"errors"
	"fmt"
	"tagcrypto"
	"testing"
)

func TestValidCrypt(t *testing.T) {
	data := []string{`test:data`, `{test:data}`}
	for _, d := range data {
		err := Crypt(d)
		if err != nil {
			t.Errorf("%v", err)
		}
	}

}

func TestInvalidCrypt(t *testing.T) {
	data := []string{`{"test":"data"}`}
	for _, d := range data {
		err := Crypt(d)
		if err == nil {
			t.Errorf("%v", err)
		}
	}

}

func TestUserKeyGeneration(t *testing.T) {
	data := []string{"abc123", "abc123456da", "abc", ""}
	for _, d := range data {
		UserKeyMaxLength := tagcrypto.UserKeyMaxLength
		userKey, err := tagcrypto.GenerateUserKey(d)
		if err != nil || len(userKey) != UserKeyMaxLength {
			t.Errorf("Error processing user password, password should be of len %v but was %v. %v", UserKeyMaxLength, len(userKey), err)
		}

	}
}

func Crypt(data string) error {
	encrypt, err := InsertTagcrypt(data)
	if err != nil {
		return errors.New("Error encrypting data: " + err.Error())
	}
	_, err = GetTagcrypt(encrypt)
	if err != nil {
		return errors.New("Error decrypting data: " + err.Error())
	}
	return nil
}

func InsertTagcrypt(data string) (tagcrypto.Payload, error) {
	var r tagcrypto.Payload
	payload := fmt.Sprintf(`{"tag_operation":"insert","user_key":"sercreth","tag_key":"","data":"%s"}`, data)
	response := tagcrypto.Tagcrypt(payload)
	err := json.Unmarshal([]byte(response), &r)
	return r, err
}

func GetTagcrypt(p tagcrypto.Payload) (tagcrypto.Payload, error) {
	var r tagcrypto.Payload
	payload := fmt.Sprintf(`{"tag_operation":"get","user_key":"%s","tag_key":"%s","data":"%s"}`, p.UserKey, p.TagKey, p.Data)
	response := tagcrypto.Tagcrypt(payload)
	err := json.Unmarshal([]byte(response), &r)
	return r, err
}
