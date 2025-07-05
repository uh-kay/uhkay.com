package main

import (
	"github.com/gin-gonic/gin"
	"uhkay.com/templates"
)

func main() {
	mainComponent := templates.Main()

	r := gin.Default()
	r.GET("/", func(c *gin.Context) {
		mainComponent.Render(c.Request.Context(), c.Writer)
	})
	r.Static("/static", "./static")

	r.Run(":8000")
}
