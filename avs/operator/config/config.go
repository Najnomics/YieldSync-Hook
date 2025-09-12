package config

import (
	"os"
	"path/filepath"

	"gopkg.in/yaml.v2"
)

// ConfigFileFlag defines the command line flag for the config file
var ConfigFileFlag = &cli.StringFlag{
	Name:     "config",
	Aliases:  []string{"c"},
	Usage:    "Path to the configuration file",
	Required: true,
}

// ReadYamlConfig reads a YAML configuration file and unmarshals it into the provided interface
func ReadYamlConfig(configPath string, config interface{}) error {
	// Check if the config file exists
	if _, err := os.Stat(configPath); os.IsNotExist(err) {
		return err
	}

	// Read the config file
	data, err := os.ReadFile(configPath)
	if err != nil {
		return err
	}

	// Unmarshal the YAML data
	err = yaml.Unmarshal(data, config)
	if err != nil {
		return err
	}

	return nil
}

// GetConfigPath returns the absolute path to the config file
func GetConfigPath(configPath string) (string, error) {
	return filepath.Abs(configPath)
}

// ValidateConfig validates the configuration
func ValidateConfig(config interface{}) error {
	// Add validation logic here
	// For now, just return nil
	return nil
}
