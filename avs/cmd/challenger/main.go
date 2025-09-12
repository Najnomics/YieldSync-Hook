package main

import (
	"context"
	"encoding/json"
	"log"
	"os"

	"github.com/urfave/cli/v2"

	"github.com/YieldSync/yieldsync-avs/challenger"
	"github.com/YieldSync/yieldsync-avs/config"
	"github.com/YieldSync/yieldsync-avs/types"
)

func main() {
	app := &cli.App{
		Flags: []cli.Flag{config.ConfigFileFlag},
		Name:  "yieldsync-challenger",
		Usage: "YieldSync Challenger",
		Description: "Service that verifies task responses and submits challenges for incorrect responses.",
		Action: challengerMain,
	}

	err := app.Run(os.Args)
	if err != nil {
		log.Fatalln("Application failed. Message:", err)
	}
}

func challengerMain(ctx *cli.Context) error {
	log.Println("Initializing YieldSync Challenger")
	
	configPath := ctx.String(config.ConfigFileFlag.Name)
	challengerConfig := types.ChallengerConfig{}
	err := config.ReadYamlConfig(configPath, &challengerConfig)
	if err != nil {
		return err
	}
	
	configJson, err := json.MarshalIndent(challengerConfig, "", "  ")
	if err != nil {
		log.Fatalf(err.Error())
	}
	log.Println("Config:", string(configJson))

	log.Println("initializing challenger")
	challenger, err := challenger.NewChallenger(challengerConfig)
	if err != nil {
		return err
	}
	log.Println("initialized challenger")

	log.Println("starting challenger")
	err = challenger.Start(context.Background())
	if err != nil {
		return err
	}
	log.Println("started challenger")

	return nil
}
