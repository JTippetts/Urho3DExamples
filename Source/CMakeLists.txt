set(URHO3D_HOME ../../Urho3D)
cmake_policy(SET CMP0015 OLD)
link_directories(../anl)
# Set project name
project (U3DExamples)

# Set minimum version
cmake_minimum_required (VERSION 2.8.6)
if (COMMAND cmake_policy)
    cmake_policy (SET CMP0003 NEW)
    if (CMAKE_VERSION VERSION_GREATER 2.8.12 OR CMAKE_VERSION VERSION_EQUAL 2.8.12)
        cmake_policy (SET CMP0022 NEW) # INTERFACE_LINK_LIBRARIES defines the link interface
    endif ()
    if (CMAKE_VERSION VERSION_GREATER 3.0.0 OR CMAKE_VERSION VERSION_EQUAL 3.0.0)
        cmake_policy (SET CMP0026 OLD) # Disallow use of the LOCATION target property - therefore we set to OLD as we still need it
        cmake_policy (SET CMP0042 NEW) # MACOSX_RPATH is enabled by default
    endif ()
endif ()

# Set CMake modules search path
set (CMAKE_MODULE_PATH ${URHO3D_HOME}/Source/CMake/Modules CACHE PATH "Path to Urho3D-specific CMake modules")
# Include Urho3D Cmake common module
include (Urho3D-CMake-common)

#set(LINK_LIBS_ONLY Bindings Builder Imaging RGBA Noise Volume PolyVoxCore PolyVoxUtil)
#SET(INCLUDE_DIRS_ONLY ../anl ../../ANLSVN/accidental-noise-library/ThirdParty/Lua/src ../../ANLSVN/accidental-noise-library/Noise ../../ANLSVN/accidental-noise-library/RGBA ../../ANLSVN/accidental-noise-library/Builder ../../ANLSVN/accidental-noise-library/Bindings ../../ANLSVN/accidental-noise-library/Imaging ../../ANLSVN/accidental-noise-library/Volume)


# Find Urho3D library
find_package (Urho3D REQUIRED)
include_directories (${URHO3D_INCLUDE_DIRS})
# Define target name
set (TARGET_NAME U3DExamplesExe)

# Define source files
define_source_files ()
# Setup target with resource copying
setup_main_executable ()