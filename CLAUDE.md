# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This repository (WPServerScriptNginx) is in early development stage. Based on the name, it appears to be intended for WordPress server automation scripts using Nginx.

## Current State

The repository currently contains minimal placeholder files:
- `README.md`: Contains only the repository title
- `build.sh`: Contains placeholder text "This is script file"

## Expected Development Direction

Given the repository name "WPServerScriptNginx", this project likely aims to provide:
- Server provisioning/configuration scripts for WordPress
- Nginx web server configuration and management
- Automation tools for WordPress deployment and maintenance

## Development Commands

Currently no build system, test framework, or automation tools are configured.

Once scripts are added, typical usage patterns may include:
- `bash build.sh` - Execute the build/deployment script (when implemented)
- Shell scripts should be made executable with `chmod +x <script>.sh`

## Architecture Notes

No architecture is currently defined. When developing this repository, consider:
- Whether to use shell scripts (bash/sh) or other scripting languages
- Configuration management approach (templates, variables, environment files)
- Target deployment environment (local, VPS, cloud providers)
- WordPress-specific requirements (PHP version, MySQL/MariaDB, SSL/TLS)
- Nginx configuration patterns (server blocks, SSL, caching, PHP-FPM integration)
