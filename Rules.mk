# Check out the documentation on creating the rules at https://ibm.github.io/ibmi-tobi/#/prepare-the-project/rules.mk
SUBDIRS := INVENTORY ACCOUNTS

# =============================================================================
# VARIABLES
# =============================================================================
PROJECT_TGTRLS := V7R5M0
PROJECT_DBGVIEW := *SOURCE

# =============================================================================
# RULES SECTION
# =============================================================================
# Add any objects at the root level here (if applicable)
# For objects in subdirectories, create Rules.mk files in each subdirectory

# =============================================================================
# WILDCARD RULES (Optional)
# =============================================================================
# Apply common settings across all modules/programs
%.MODULE: private TGTRLS := $(PROJECT_TGTRLS)
%.MODULE: private DBGVIEW := $(PROJECT_DBGVIEW)

%.PGM: private TGTRLS := $(PROJECT_TGTRLS)
%.PGM: private DBGVIEW := $(PROJECT_DBGVIEW)