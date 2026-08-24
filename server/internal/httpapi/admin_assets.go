package httpapi

import (
	"embed"
	"io/fs"
)

//go:embed admin/index.html admin/app.css admin/app.js
var adminFiles embed.FS

func adminFile(name string) ([]byte, error) {
	return fs.ReadFile(adminFiles, "admin/"+name)
}
