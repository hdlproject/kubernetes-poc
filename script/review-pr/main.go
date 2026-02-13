package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"
)

const (
	claudeAPI  = "https://api.anthropic.com/v1/messages"
	githubAPI  = "https://api.github.com"
	claudeModel = "claude-sonnet-4-5-20250929"
	maxDiffLen = 90000
)

type claudeRequest struct {
	Model     string         `json:"model"`
	MaxTokens int            `json:"max_tokens"`
	System    string         `json:"system"`
	Messages  []claudeMessage `json:"messages"`
}

type claudeMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type claudeResponse struct {
	Content []struct {
		Text string `json:"text"`
	} `json:"content"`
	Error *struct {
		Type    string `json:"type"`
		Message string `json:"message"`
	} `json:"error"`
}

func mustEnv(key string) string {
	v := os.Getenv(key)
	if v == "" {
		fmt.Fprintf(os.Stderr, "Error: %s is required\n", key)
		os.Exit(1)
	}
	return v
}

func main() {
	githubToken := mustEnv("GITHUB_TOKEN")
	claudeKey := mustEnv("CLAUDE_API_KEY")
	prNumber := mustEnv("PR_NUMBER")
	repo := mustEnv("REPO")
	prTitle := os.Getenv("PR_TITLE")
	prBody := os.Getenv("PR_BODY")
	skillFile := os.Getenv("SKILL_FILE")
	if skillFile == "" {
		skillFile = ".github/skills/pr-content-reviewer.md"
	}

	// 1. Read system prompt from skill file
	systemPromptBytes, err := os.ReadFile(skillFile)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error reading skill file %s: %v\n", skillFile, err)
		os.Exit(1)
	}
	systemPrompt := string(systemPromptBytes)

	// 2. Fetch PR diff
	fmt.Printf("Fetching diff for PR #%s in %s...\n", prNumber, repo)
	diff, err := fetchDiff(githubToken, repo, prNumber)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error fetching diff: %v\n", err)
		os.Exit(1)
	}
	if diff == "" {
		fmt.Println("No diff found — skipping review.")
		return
	}
	if len(diff) > maxDiffLen {
		diff = diff[:maxDiffLen] + "\n... (diff truncated)"
		fmt.Printf("Diff truncated to %d characters.\n", maxDiffLen)
	}

	// 3. Call Claude API
	userContent := fmt.Sprintf("PR Title: %s\n\nPR Description:\n%s\n\nDiff:\n```diff\n%s\n```", prTitle, prBody, diff)

	fmt.Println("Sending diff to Claude for review...")
	review, err := callClaude(claudeKey, systemPrompt, userContent)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error calling Claude API: %v\n", err)
		os.Exit(1)
	}
	fmt.Printf("Review received (%d chars).\n", len(review))

	// 4. Post comment on PR
	comment := "## Claude Code Review\n\n" + review
	fmt.Printf("Posting comment to PR #%s...\n", prNumber)
	if err := postComment(githubToken, repo, prNumber, comment); err != nil {
		fmt.Fprintf(os.Stderr, "Error posting comment: %v\n", err)
		os.Exit(1)
	}
	fmt.Println("Comment posted successfully.")
}

func fetchDiff(token, repo, prNumber string) (string, error) {
	url := fmt.Sprintf("%s/repos/%s/pulls/%s", githubAPI, repo, prNumber)
	req, _ := http.NewRequest("GET", url, nil)
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Accept", "application/vnd.github.v3.diff")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", err
	}
	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("GitHub API returned %d: %s", resp.StatusCode, string(body))
	}
	return string(body), nil
}

func callClaude(apiKey, systemPrompt, userContent string) (string, error) {
	reqBody := claudeRequest{
		Model:     claudeModel,
		MaxTokens: 4096,
		System:    systemPrompt,
		Messages: []claudeMessage{
			{Role: "user", Content: userContent},
		},
	}

	jsonBytes, err := json.Marshal(reqBody)
	if err != nil {
		return "", fmt.Errorf("failed to marshal request: %w", err)
	}

	req, _ := http.NewRequest("POST", claudeAPI, bytes.NewReader(jsonBytes))
	req.Header.Set("x-api-key", apiKey)
	req.Header.Set("anthropic-version", "2023-06-01")
	req.Header.Set("content-type", "application/json")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", err
	}

	var result claudeResponse
	if err := json.Unmarshal(body, &result); err != nil {
		return "", fmt.Errorf("failed to parse response: %w\nraw: %s", err, string(body))
	}

	if result.Error != nil {
		return "", fmt.Errorf("API error (%s): %s", result.Error.Type, result.Error.Message)
	}

	if len(result.Content) == 0 || result.Content[0].Text == "" {
		return "", fmt.Errorf("empty response from Claude\nraw: %s", string(body))
	}

	return result.Content[0].Text, nil
}

func postComment(token, repo, prNumber, body string) error {
	url := fmt.Sprintf("%s/repos/%s/issues/%s/comments", githubAPI, repo, prNumber)
	payload := map[string]string{"body": body}
	jsonBytes, _ := json.Marshal(payload)

	req, _ := http.NewRequest("POST", url, bytes.NewReader(jsonBytes))
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Accept", "application/vnd.github.v3+json")
	req.Header.Set("Content-Type", "application/json")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		respBody, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("GitHub API returned %d: %s", resp.StatusCode, strings.TrimSpace(string(respBody)))
	}
	return nil
}
