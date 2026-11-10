#
# 本机构建适配文件（非 Flutter 生成，pub get 不会覆盖）。
#
# Flutter 生成的 .plugin_symlinks 指向 C: 盘 pub 缓存，在部分 Windows
# 环境中跨卷装入点被判定为不受信任，CMake 无法遍历。这里改为从
# .dart_tool/package_config.json 解析插件包的真实路径，效果等价。
#

list(APPEND FLUTTER_PLUGIN_LIST
  hotkey_manager_windows
  screen_retriever_windows
  url_launcher_windows
  window_manager
)

list(APPEND FLUTTER_FFI_PLUGIN_LIST
  flutter_soloud
  jni
)

# smtc_windows 由 Rust/CargoKit 构建。部分 Windows 环境中 rustup 的
# cargo/rustc 符号链接不可遍历，此时自动降级为复用已编译的 DLL，
# 而不是让整个构建失败；工具链正常时仍按官方方式编译该插件。
find_program(CARGOKIT_CARGO_EXECUTABLE cargo)
set(CARGO_PROBE_RESULT 1)
if(CARGOKIT_CARGO_EXECUTABLE)
  execute_process(
    COMMAND "${CARGOKIT_CARGO_EXECUTABLE}" --version
    RESULT_VARIABLE CARGO_PROBE_RESULT
    OUTPUT_QUIET ERROR_QUIET)
endif()
if(CARGO_PROBE_RESULT STREQUAL "0")
  list(APPEND FLUTTER_FFI_PLUGIN_LIST smtc_windows)
else()
  message(STATUS "smtc_windows: Rust toolchain unavailable, skipping CargoKit build")
endif()

set(PLUGIN_BUNDLED_LIBRARIES)

if(NOT CARGO_PROBE_RESULT STREQUAL "0")
  set(SMTC_PREBUILT_DLL "${CMAKE_BINARY_DIR}/plugins/smtc_windows/Debug/smtc_windows.dll")
  if(EXISTS "${SMTC_PREBUILT_DLL}")
    list(APPEND PLUGIN_BUNDLED_LIBRARIES "${SMTC_PREBUILT_DLL}")
  endif()
endif()

set(PACKAGE_CONFIG_FILE "${CMAKE_CURRENT_SOURCE_DIR}/../.dart_tool/package_config.json")
file(READ "${PACKAGE_CONFIG_FILE}" PACKAGE_CONFIG_JSON)

foreach(plugin ${FLUTTER_PLUGIN_LIST} ${FLUTTER_FFI_PLUGIN_LIST})
  string(REGEX MATCH
    "\"name\"[ \t\r\n]*:[ \t\r\n]*\"${plugin}\"[ \t\r\n]*,[ \t\r\n]*\"rootUri\"[ \t\r\n]*:[ \t\r\n]*\"([^\"]+)\""
    PLUGIN_PATH_MATCH "${PACKAGE_CONFIG_JSON}")
  if(NOT PLUGIN_PATH_MATCH)
    message(FATAL_ERROR "Cannot resolve ${plugin} from ${PACKAGE_CONFIG_FILE}")
  endif()
  string(REGEX REPLACE "^file:///" "" PLUGIN_ROOT "${CMAKE_MATCH_1}")
  set(LOCAL_PLUGIN_PATH_${plugin} "${PLUGIN_ROOT}")
endforeach()

foreach(plugin ${FLUTTER_PLUGIN_LIST})
  set(PLUGIN_DIR_VAR "LOCAL_PLUGIN_PATH_${plugin}")
  add_subdirectory("${${PLUGIN_DIR_VAR}}/windows" "plugins/${plugin}")
  target_link_libraries(${BINARY_NAME} PRIVATE ${plugin}_plugin)
  list(APPEND PLUGIN_BUNDLED_LIBRARIES $<TARGET_FILE:${plugin}_plugin>)
  list(APPEND PLUGIN_BUNDLED_LIBRARIES ${${plugin}_bundled_libraries})
endforeach(plugin)

foreach(ffi_plugin ${FLUTTER_FFI_PLUGIN_LIST})
  set(PLUGIN_DIR_VAR "LOCAL_PLUGIN_PATH_${ffi_plugin}")
  add_subdirectory("${${PLUGIN_DIR_VAR}}/windows" "plugins/${ffi_plugin}")
  list(APPEND PLUGIN_BUNDLED_LIBRARIES ${${ffi_plugin}_bundled_libraries})
endforeach(ffi_plugin)
