package commands

import (
	"fmt"
	"strings"

	"github.com/go-zoox/cli"
	"github.com/go-zoox/commands-as-a-service/client"
	"github.com/go-zoox/commands-as-a-service/entities"
	"github.com/go-zoox/core-utils/regexp"
	"github.com/go-zoox/fs"
	"github.com/go-zoox/logger"
)

func RegistryClient(app *cli.MultipleProgram) {
	app.Register("client", &cli.Command{
		Name:  "client",
		Usage: "commands as a service client",
		Flags: []cli.Flag{
			&cli.StringFlag{
				Name:    "server",
				Usage:   "server url",
				Aliases: []string{"s"},
				EnvVars: []string{"CAAS_SERVER"},
				// Required: true,
				Value: "127.0.0.1",
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

			// fix auto exit
			cfg.AutoExit = true

			if ctx.String("server") != "" {
				cfg.Server = ctx.String("server")
			}

			if ctx.String("client-id") != "" {
				cfg.ClientID = ctx.String("client-id")
			}

			if ctx.String("client-secret") != "" {
				cfg.ClientSecret = ctx.String("client-secret")
			}

			// add scheme
			if !regexp.Match("^wss?://", cfg.Server) {
				cfg.Server = fmt.Sprintf("ws://%s", cfg.Server)
			}

			// add port
			if !regexp.Match(":\\d+$", cfg.Server) {
				// host:port
				cfg.Server = fmt.Sprintf("%s:8838", cfg.Server)
			}

			if !regexp.Match("^ws://[^:]+:\\d+", cfg.Server) {
				return fmt.Errorf("invalid gzcaas server: %s", cfg.Server)
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

			// i := 0
			// for {
			// 	i += 1
			// 	if i >= 10 {
			// 		break
			// 	}

			// 	go func() {
			// 		fmt.Println("adasdad: ", i)

			// 		c := client.New(cfg)
			// 		if err := c.Connect(); err != nil {
			// 			logger.Errorf("failed to connect to server: %s", err)
			// 			// return fmt.Errorf("server is not running (server: %s)", ctx.String("server"))
			// 		}

			// 		c.Exec(&entities.Command{
			// 			Script:      script,
			// 			Environment: environment,
			// 		})
			// 	}()
			// }

			// time.Sleep(5 * time.Second)
			// return

			c := client.New(cfg)
			if err := c.Connect(); err != nil {
				logger.Debugf("failed to connect to server: %s", err)
				return fmt.Errorf("server(%s) is not running", ctx.String("server"))
			}

			return c.Exec(&entities.Command{
				Script:      script,
				Environment: environment,
			})
		},
	})
}
