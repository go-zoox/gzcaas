package main

import (
	"github.com/go-idp/agent/cmd/agent/commands"
	"github.com/go-zoox/cli"
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
	// shell
	commands.RegistryShell(app)

	app.Run()
}
