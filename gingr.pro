######################################################################
# gingr.pro - Main project file
# Builds harvest library and Gingr GUI application
######################################################################

TEMPLATE = subdirs

# Build order - harvest library must be built first
SUBDIRS = \
    harvest \
    gingr_app

# Dependency: gingr_app requires harvest library
gingr_app.depends = harvest
