package main

import (
	"fmt"

	"github.com/go-idp/agent/cmd/agent/commands"
	"github.com/go-zoox/chalk"
	"github.com/go-zoox/cli"
)

func main() {
// 	fmt.Printf(`
//    _______  ___    _____    _____          ____
//   /  _/ _ \/ _ \  / ___/__ / ___/__ ____ _/ __/
//  _/ // // / ___/ / (_ /_ // /__/ _ '/ _ '/\ \  
// /___/____/_/     \___//__/\___/\_,_/\_,_/___/  
//                                                    %s

// ____________________________________O/_______
//                                     O\
// `, chalk.Green("v"+Version))

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
