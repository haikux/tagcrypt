package tagcrypto

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"

	jwt "github.com/dvsekhvalnov/jose2go"
)

// UserKeyMaxLength User input key max length
const UserKeyMaxLength int = 10

// AutoKeyMaxLength auto generated key max length
const AutoKeyMaxLength int = 11

// Payload struct stores data exchanged b/w flutter and Go
type Payload struct {
	/*
		tag_operation: either "insert" (Encrypt data) or "get" (Decrypt)
		user_key: user password maximum of 11 characters
		tag_key: token data stored in NFC tag, if get operation is performed else empty string
		data: Encrypted data, if get operation is performed else empty string
	*/
	TagOperation string `json:"tag_operation"`
	UserKey      string `json:"user_key"`
	TagKey       string `json:"tag_key"`
	Data         string `json:"data"`
}

// Encrypt data using combination of user password & Auto generated key
func jwtEncrypt(c string, sigKey []byte) (string, error) {
	// A256GCM encryption supports token of size 256 bits
	token, err := jwt.Encrypt(c, jwt.DIR, jwt.A256GCM, sigKey, jwt.Zip(jwt.DEF))
	if err != nil {
		fmt.Println("Error signing JWT token ", err)
	}
	return token, err
}

// Decrypt data combining User password and Key stored in the NFC TAG
func jwtDecrypt(secretKey []byte, token string) (string, error) {
	payload, _, err := jwt.Decode(token, secretKey)

	if err != nil {
		fmt.Println("Error verifying JWT token ", err)
		return payload, err
	}
	return payload, err
}

// RandomKeyGen generate random hex string of any given length
func RandomKeyGen(n int) (string, error) {
	// Generate random hex string of any given length
	KeyGen := make([]byte, n)
	_, err := rand.Read(KeyGen)
	return hex.EncodeToString(KeyGen), err
}

//GenerateUserKey if user input password is less than UserKeyMaxlength
func GenerateUserKey(encKeyUser string) (string, error) {
	if len(encKeyUser) < UserKeyMaxLength {
		genUserKey, err := RandomKeyGen(UserKeyMaxLength - len(encKeyUser))
		if err != nil {
			return "", err
		}
		encKeyUser += genUserKey
		encKeyUser = encKeyUser[:UserKeyMaxLength]
	} else {
		encKeyUser = encKeyUser[:UserKeyMaxLength]
	}
	return encKeyUser, nil
}

// Tagcrypt is called from Flutter
func Tagcrypt(payload string) string {
	var p Payload

	err := json.Unmarshal([]byte(payload), &p)
	if err != nil {
		fmt.Println(err)
		return "Error str->json " + err.Error()
	}
	var response string
	var status string

	// User entered password
	encKeyUser := p.UserKey
	// Key stored in NFC Tag
	tagKey := p.TagKey

	/*
		Perform insert operation to encrypt data
		Perform get opertation decrypt
	*/
	if p.TagOperation == "insert" {
		// generate new key for NFC tag
		encKeyAuto, _ := RandomKeyGen(AutoKeyMaxLength)

		// Auto fill password for user, if length of pwd less than UserKeyMaxLength
		encKeyUser, _ = GenerateUserKey(encKeyUser)
		// Generate JWT signing token by combining user password and auto generated key.
		encKey := []byte(encKeyUser + encKeyAuto)
		payloadData := p.Data

		token, err := jwtEncrypt(payloadData, encKey)
		status = "success"
		if err != nil {
			status = "failed"
		}
		response = fmt.Sprintf(`{"tag_operation":"insert","user_key":"%s","tag_key":"%s","data":"%s","status":"%s"}`, encKeyUser, encKeyAuto, token, status)
	} else if p.TagOperation == "get" {
		encKey := []byte(encKeyUser + tagKey)
		encToken := p.Data
		verifiedToken, err := jwtDecrypt(encKey, encToken)
		status = "success"
		if err != nil {
			status = "failed"
		}
		response = fmt.Sprintf(`{"tag_operation":"get","user_key":"%s","tag_key":"","data":"%s","status":"%s"}`, encKeyUser, verifiedToken, status)
	} else {
		status = "failed"
		response = fmt.Sprintf(`{"tag_operation":"get","user_key":"","tag_key":"","data":"only insert/get method supported","status":"%s"}`, status)
	}
	return response
}
