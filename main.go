package main

import (
	"embed"
	"io/fs"
	"net/http"

	"github.com/gin-gonic/gin"
	"uhkay.com/templates"
)

//go:embed all:static
var staticFiles embed.FS

func main() {
	mainComponent := templates.Main()

	r := gin.Default()
	r.SetTrustedProxies(nil)
	r.GET("/", func(c *gin.Context) {
		mainComponent.Render(c.Request.Context(), c.Writer)
	})

	staticFS, err := fs.Sub(staticFiles, "static")
	if err != nil {
		panic(err)
	}
	r.StaticFS("/static", http.FS(staticFS))

	r.Run(":8000")
}
