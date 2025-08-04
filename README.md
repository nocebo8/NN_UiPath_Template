# UiPath REFramework Template

This repository provides a sample project built on UiPath's **Robotic Enterprise Framework**.
Use it as a starting point for building robust attended or unattended automations.

## Prerequisites

- UiPath Studio 2024.10 or later
- Optional: access to UiPath Orchestrator for queues and assets

## Setup

1. Clone this repository.
2. Open the `Golden_Template` folder in UiPath Studio.
3. Restore dependencies when prompted.
4. Review `Data/Config.xlsx` to configure application settings and assets.

## Key Files and Folders

- `Golden_Template/Main.xaml` – main workflow that drives the state machine
- `Golden_Template/Framework/` – core framework workflows such as `InitAllSettings.xaml`
- `Golden_Template/Data/` – contains `Config.xlsx` plus input and output folders
- `Golden_Template/Documentation/` – PDF documentation of the framework

## Basic Usage

1. Update the configuration file and any application-specific workflows in the `Framework` folder.
2. Press **Run** in UiPath Studio to execute `Main.xaml`.
3. Inspect logs and screenshots (saved in `Exceptions_Screenshots/`) if exceptions occur.

