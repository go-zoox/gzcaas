package commands

import (
	"fmt"
	"strings"

	"github.com/go-zoox/cli"
	"github.com/go-zoox/commands-as-a-service/client"
	"github.com/go-zoox/fs"
)

func RegistryClient(app *cli.MultipleProgram) {
	app.Register("client", &cli.Command{
		Name:  "client",
		Usage: "commands as a service client",
		Flags: []cli.Flag{
			&cli.StringFlag{
				Name:     "server",
				Usage:    "server url",
				Aliases:  []string{"s"},
				EnvVars:  []string{"CAAS_SERVER"},
				Required: true,
			},
			&cli.StringFlag{
				Name:    "script",
				Usage:   "specify command script",
				EnvVars: []string{"CAAS_SCRIPT"},
				// Required: true,
			},
			&cli.StringFlag{
				Name:    "client-id",
				Usage:   "Auth Client ID",
				EnvVars: []string{"CAAS_CLIENT_ID"},
			},
			&cli.StringFlag{
				Name:    "client-secret",
				Usage:   "Auth Client Secret",
				EnvVars: []string{"CAAS_CLIENT_SECRET"},
			},
			//
			&cli.StringFlag{
				Name:    "scriptfile",
				Usage:   "specify command script path",
				EnvVars: []string{"CAAS_SCRIPT_FILE"},
			},
			&cli.StringFlag{
				Name:    "envfile",
				Usage:   "specify command envfile file path",
				EnvVars: []string{"CAAS_ENV_FILE"},
			},
		},
		Action: func(ctx *cli.Context) (err error) {
			script := ctx.String("script")
			environment := map[string]string{}

			if scriptPath := ctx.String("scriptfile"); scriptPath != "" {
				if ok := fs.IsExist(scriptPath); !ok {
					return fmt.Errorf("script path not found: %s", scriptPath)
				}

				if scriptText, err := fs.ReadFileAsString(scriptPath); err != nil {
					return fmt.Errorf("failed to read script file: %s", err)
				} else {
					script = scriptText
				}
			}

			if envfilePath := ctx.String("envfile"); envfilePath != "" {
				if ok := fs.IsExist(envfilePath); !ok {
					return fmt.Errorf("envfile path not found: %s", envfilePath)
				}

				lines, err := fs.ReadFileLines(envfilePath)
				if err != nil {
					return fmt.Errorf("failed to read envfile: %s", err)
				}

				for _, line := range lines {
					if line == "" {
						continue
					}

					if line[0] == '#' {
						continue
					}

					parts := strings.SplitN(line, "=", 2)
					if len(parts) != 2 {
						return fmt.Errorf("invalid envfile line: %s", line)
					}

					environment[parts[0]] = parts[1]
				}
			}

			if script == "" {
				return fmt.Errorf("script is required")
			}

			return client.
				New(&client.Config{
					Server:       ctx.String("server"),
					Script:       script,
					Environment:  environment,
					ClientID:     ctx.String("client-id"),
					ClientSecret: ctx.String("client-secret"),
				}).
				Run()
		},
	})
}
