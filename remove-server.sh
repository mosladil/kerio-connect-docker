#!/bin/bash

. common.sh

printBanner
stopContainer IGNORE_STATE
removeContainer
removeStore
