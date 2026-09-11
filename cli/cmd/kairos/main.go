package main

import (
	"os"

	"github.com/YuKiBi0/kairos/cli/internal/app"
)

func main() {
	exitCode := app.Run(os.Args[1:], os.Stdout, os.Stderr)
	os.Exit(exitCode)
}
