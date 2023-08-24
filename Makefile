-include .env

.PHONY: all test clean deploy fund help install snapshot format anvil 

LOCAL_KEYS=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

ETHERSCAN_API_KEY=TZZ6UPCG3NZDF7V5T4QRM7G3R8RRKY4JKN



help:
	@echo "Usage:"	
	@echo "  make deploy [ARGS=...]\n    example: make deploy ARGS=\"--network sepolia\""
	@echo ""
	@echo "  make fund [ARGS=...]\n    example: make deploy ARGS=\"--network sepolia\""

all: clean remove install update build

# Clean the repo
clean  :; forge clean

# Remove modules
remove :; rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"

install :; forge install Cyfrin/foundry-devops@0.0.11 --no-commit && forge install smartcontractkit/chainlink-brownie-contracts@0.6.1 --no-commit && forge install foundry-rs/forge-std@v1.5.3 --no-commit && forge install transmissions11/solmate@v6 --no-commit

# Update Dependencies
update:; forge update

build:; forge build

test :; forge test 

snapshot :; forge snapshot

format :; forge fmt


#To create Localhost Anvil Network

anvil :; anvil -m 'test test test test test test test test test test test junk' 

NETWORK_ARGS := --rpc-url http://localhost:8545 --private-key $(LOCAL_KEYS) --broadcast

ifeq ($(findstring --network sepolia,$(ARGS)),--network sepolia)
	NETWORK_ARGS := --rpc-url $(SPL_URL) --private-key $(PRIVATE_KEYS) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv
endif

deploy:
	@forge script script/DeployScript.s.sol:Deploy $(NETWORK_ARGS)

createSubscription:
	@forge script script/interaction.s.sol:createSubscription $(NETWORK_ARGS)

addConsumer:
	@forge script script/interaction.s.sol:AddConsumer $(NETWORK_ARGS)

fundSubscription:
	@forge script script/interaction.s.sol:FundSubscription $(NETWORK_ARGS)