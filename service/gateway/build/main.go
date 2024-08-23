package main

import (
	"database/sql"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strings"

	_ "github.com/lib/pq"
)

const (
	postgresqlDSN = "host=postgresql port=5432 user=postgres password=postgres dbname=%s sslmode=disable"
)

func main() {
	http.HandleFunc("/health", checkHealth)
	http.HandleFunc("/info", getInfo)

	db, err := connectDatabase()
	if err != nil {
		log.Fatal(err)
		return
	}
	if db != nil {
		defer db.Close()
	}

	err = http.ListenAndServe(":8000", nil)
	if err != nil {
		log.Fatal(err)
	}
}

func connectDatabase() (*sql.DB, error) {
	databaseName := os.Getenv("DATABASE")

	if databaseName == "" {
		return nil, nil
	}

	db, err := sql.Open("postgres", fmt.Sprintf(postgresqlDSN, databaseName))
	if err != nil {
		return nil, err
	}

	return db, nil
}

func checkHealth(w http.ResponseWriter, _ *http.Request) {
	log.Println("checkHealth")

	w.WriteHeader(http.StatusOK)
	io.WriteString(w, "success")
}

func getInfo(w http.ResponseWriter, _ *http.Request) {
	log.Println("getInfo")

	appName := os.Getenv("APPNAME")

	upstreamsVar := strings.Trim(os.Getenv("UPSTREAMS"), " ")
	if upstreamsVar == "" {
		w.WriteHeader(http.StatusOK)
		io.WriteString(w, appName)
		return
	}

	upstreams := strings.Split(upstreamsVar, ",")

	var result string
	for _, upstream := range upstreams {
		res, err := hitHTTPEndpoint(upstream + "/info")
		if err != nil {
			log.Println(fmt.Errorf("hit http endpoint: %w", err))

			w.WriteHeader(http.StatusBadRequest)
			return
		}

		result += res + " "
	}

	w.WriteHeader(http.StatusOK)
	io.WriteString(w, appName+" "+result)
	return
}

func hitHTTPEndpoint(upstream string) (string, error) {
	req, err := http.NewRequest("GET", upstream, nil)
	if err != nil {
		return "", fmt.Errorf("new request: %w", err)
	}

	res, err := http.DefaultClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("do call: %w", err)
	}

	resByte, err := io.ReadAll(res.Body)
	if err != nil {
		return "", fmt.Errorf("read body: %w", err)
	}

	return string(resByte), nil
}
