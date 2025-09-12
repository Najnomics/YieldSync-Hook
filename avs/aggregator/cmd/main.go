package main

import (
	"context"
	"encoding/json"
	"log"
	"os"

	"github.com/urfave/cli/v2"

	"github.com/YieldSync/yieldsync-operator/aggregator"
	"github.com/YieldSync/yieldsync-operator/core/config"
)

func main() {
	app := &cli.App{
		Flags: []cli.Flag{config.ConfigFileFlag},
		Name:  "yieldsync-aggregator",
		Usage: "YieldSync Aggregator",
		Description: "Service that aggregates operator signatures and submits task responses to the blockchain.",
		Action: aggregatorMain,
	}

	err := app.Run(os.Args)
	if err != nil {
		log.Fatalln("Application failed. Message:", err)
	}
}

func aggregatorMain(ctx *cli.Context) error {
	log.Println("Initializing YieldSync Aggregator")
	
	configPath := ctx.String(config.ConfigFileFlag.Name)
	aggregatorConfig, err := config.NewConfig(ctx)
	if err != nil {
		return err
	}
	
	configJson, err := json.MarshalIndent(aggregatorConfig, "", "  ")
	if err != nil {
		log.Fatalf(err.Error())
	}
	log.Println("Config:", string(configJson))

	log.Println("initializing aggregator")
	aggregator, err := aggregator.NewAggregator(*aggregatorConfig)
	if err != nil {
		return err
	}
	log.Println("initialized aggregator")

	log.Println("starting aggregator")
	err = aggregator.Start(context.Background())
	if err != nil {
		return err
	}
	log.Println("started aggregator")

	return nil
}
