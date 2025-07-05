package main

import (
	"embed"
	"net/http"

	"github.com/gin-gonic/gin"
	"uhkay.com/templates"
)

//go:embed static
var staticFiles embed.FS

func main() {
	mainComponent := templates.Main()

	r := gin.Default()
	r.GET("/", func(c *gin.Context) {
		mainComponent.Render(c.Request.Context(), c.Writer)
	})
	r.StaticFS("/static", http.FS(staticFiles))

	r.Run(":8000")
}
