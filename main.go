package main

import (
	"context"
	"embed"
	"log"
	"os"
	"path/filepath"

	"github.com/a-h/templ"
	"uhkay.com/templates"
)

//go:embed all:static
var staticFiles embed.FS

func main() {
	if err := renderTempltoFile("./", "index.html", templates.Index()); err != nil {
		log.Fatal(err)
	}

	if err := renderTempltoFile("./static", "about.html", templates.About()); err != nil {
		log.Fatal(err)
	}

	if err := renderTempltoFile("./static", "projects.html", templates.Projects()); err != nil {
		log.Fatal(err)
	}
}

func renderTempltoFile(folder, filename string, component templ.Component) error {
	path := filepath.Join(folder, filename)
	f, err := os.Create(path)
	if err != nil {
		return err
	}
	defer f.Close()

	return component.Render(context.Background(), f)
}
