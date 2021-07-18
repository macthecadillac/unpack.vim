# Unpack (tentative name)

A lightweight plugin manager that disappears into the ether.

## Table of Contents

1. [Introduction](#introduction)
2. [Features](#features)
3. [Requirements](#requirements)
4. [Installation](#installation)
5. [Bootstrapping](#bootstrapping)
6. [Configuration](#configuration)

## Introduction

Unpack is a featherweight package manager for Vim/Neovim written in pure vim
script. Inspired by [`packer.nvim`](https://github.com/wbthomason/packer.nvim),
it aims to have zero/very low startup overhead without compromising the features
available.

## Features

- Supports both Vim and Neovim

- Uses the `pack-add` mechanism introduced in Vim8 which Neovim also merged

- Very low startup overhead. This is achieved by utilizing the built-in
  `pack-add` mechanism and an auto-generated loader plugin which handles package
  loading without most of the complicated logic that might slow down load time.
  The overhead can be zero if your entire configuration does not utilize
  lazy-loading or that it only requires file type based lazy-loading. 

- Dependency resolution for package lazy-loading where a loader will lazy-load
  packages and their dependencies in the correct order. Note: `apt` style
  dependency resolution is not available for package management and the user
  should include dependencies of packages manually since there is not/might
  never be a dependency specification standard in vim-land.

## Requirements

Neovim/Vim with `pack-add`

## Installation

## Bootstrapping

## Configuration
