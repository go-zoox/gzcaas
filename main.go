package main

import (
	"github.com/go-zoox/cli"
	"github.com/go-zoox/gzcaas/commands"
)

func main() {
	app := cli.NewMultipleProgram(&cli.MultipleProgramConfig{
		Name:    "gzcaas",
		Usage:   "The easiest way to use Commands as a Service",
		Version: Version,
	})

	// server
	commands.RegistryServer(app)
	// client
	commands.RegistryClient(app)

	app.Run()
}
