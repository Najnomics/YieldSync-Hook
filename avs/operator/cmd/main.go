package main

import (
	"context"
	"encoding/json"
	"log"
	"os"

	"github.com/urfave/cli/v2"

	"github.com/YieldSync/yieldsync-operator/config"
	"github.com/YieldSync/yieldsync-operator/operator"
	"github.com/YieldSync/yieldsync-operator/types"
)

func main() {
	app := &cli.App{
		Flags: []cli.Flag{config.ConfigFileFlag},
		Name:  "yieldsync-operator",
		Usage: "YieldSync Operator",
		Description: "Service that monitors LST yield rates, signs yield data, and sends them to the aggregator.",
		Action: operatorMain,
	}

	err := app.Run(os.Args)
	if err != nil {
		log.Fatalln("Application failed. Message:", err)
	}
}

func operatorMain(ctx *cli.Context) error {
	log.Println("Initializing YieldSync Operator")
	
	configPath := ctx.String(config.ConfigFileFlag.Name)
	nodeConfig := types.NodeConfig{}
	err := config.ReadYamlConfig(configPath, &nodeConfig)
	if err != nil {
		return err
	}
	
	configJson, err := json.MarshalIndent(nodeConfig, "", "  ")
	if err != nil {
		log.Fatalf(err.Error())
	}
	log.Println("Config:", string(configJson))

	log.Println("initializing operator")
	operator, err := operator.NewOperatorFromConfig(nodeConfig)
	if err != nil {
		return err
	}
	log.Println("initialized operator")

	log.Println("starting operator")
	err = operator.Start(context.Background())
	if err != nil {
		return err
	}
	log.Println("started operator")

	return nil
}
