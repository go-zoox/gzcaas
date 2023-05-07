package commands

import (
	"fmt"
	"strings"

	"github.com/go-zoox/cli"
	"github.com/go-zoox/commands-as-a-service/client"
	"github.com/go-zoox/commands-as-a-service/entities"
	"github.com/go-zoox/core-utils/regexp"
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
			cfg := &client.Config{}
			if err := cli.LoadConfig(ctx, cfg); err != nil {
				return fmt.Errorf("failed to load config file: %v", err)
			}

			if ctx.String("server") != "" {
				cfg.Server = ctx.String("server")
			}

			if ctx.String("client-id") != "" {
				cfg.ClientID = ctx.String("client-id")
			}

			if ctx.String("client-secret") != "" {
				cfg.ClientSecret = ctx.String("client-secret")
			}

			// host only
			if regexp.Match("^\\d+\\.\\d+\\.\\d+\\.\\d+$", cfg.Server) {
				cfg.Server = fmt.Sprintf("ws://%s:8838", cfg.Server)
			} else if regexp.Match("^\\d+\\.\\d+\\.\\d+\\.\\d+:\\d+$", cfg.Server) {
				// host:port
				cfg.Server = fmt.Sprintf("ws://%s", cfg.Server)
			}

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

			c := client.New(cfg)
			if err := c.Connect(); err != nil {
				return fmt.Errorf("failed to connect to server: %s", err)
			}

			return c.Exec(&entities.Command{
				Script:      script,
				Environment: environment,
			})
		},
	})
}
