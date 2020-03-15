#!/usr/bin/env bash
##
# Run DrevOps tests in CI.
#
# This file is removed after install/update.

set -e
[ -n "${DREVOPS_DEBUG}" ] && set -x

[ "$(git config --global user.name)" == "" ] && echo "==> Configuring global git user name" && git config --global user.name "Test user"
[ "$(git config --global user.email)" == "" ] && echo "==> Configuring global git user email" && git config --global user.email "someone@example.com"

# Create stub of local framework.
docker network create amazeeio-network || true

echo "==> Lint scripts code"
scripts/drevops/lint-scripts.sh

echo "==> Check spelling"
scripts/drevops/lint-spelling.sh

echo "==> Run Drevops unit tests"
pushd scripts/drevops/tests || exit 1
composer install --no-suggest -n --ansi
vendor/bin/phpunit unit
popd || exit 1

echo "==> Test BATS helpers"
bats scripts/drevops/tests/bats/helpers.bats --tap

echo "==> Test installation"
bats scripts/drevops/tests/bats/env.bats --tap
bats scripts/drevops/tests/bats/install_initial.bats --tap
bats scripts/drevops/tests/bats/install_existing.bats --tap
bats scripts/drevops/tests/bats/install_parameters.bats --tap
bats scripts/drevops/tests/bats/install_integrations.bats --tap
bats scripts/drevops/tests/bats/install_demo.bats --tap
bats scripts/drevops/tests/bats/clean.bats --tap
bats scripts/drevops/tests/bats/update.bats --tap

# @todo:d
# [ -n "${DATABASE_IMAGE}" ] && workflow=didi || workflow=dif
index="${CIRCLE_NODE_INDEX:-*}"
echo "==> Test workflows (${index})"
bats "scripts/drevops/tests/bats/workflow${index}.bats" --tap
