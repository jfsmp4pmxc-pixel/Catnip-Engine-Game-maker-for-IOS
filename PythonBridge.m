// PythonBridge.m — khởi tạo CPython một lần, chạy script bằng runpy. Chưa build/kiểm chứng.

#import "PythonBridge.h"

#ifdef CATNIP_HAS_PYTHON
#if __has_include(<Python/Python.h>)
#import <Python/Python.h>
#else
#include <Python.h>
#endif

static BOOL gInitialized = NO;
static NSString *gInitError = nil;

// Mã chạy trong interpreter: dọn module của lần chạy trước rồi chạy script.
static const char *kPrelude =
"import sys, os, io, runpy, traceback\n"
"_catnip_base = set(sys.modules)\n"
"def _catnip_run(path, cwd):\n"
"    for m in [m for m in sys.modules if m not in _catnip_base]:\n"
"        del sys.modules[m]\n"
"    os.chdir(cwd)\n"
"    sys.path[:] = [p for p in sys.path if p != cwd]\n"
"    sys.path.insert(0, cwd)\n"
"    sys.argv = [path]\n"
"    try:\n"
"        sys.stdin = open(0, 'r', encoding='utf-8', closefd=False)\n"
"        sys.stdout = io.TextIOWrapper(io.FileIO(1, 'w', closefd=False), encoding='utf-8', write_through=True)\n"
"        sys.stderr = io.TextIOWrapper(io.FileIO(2, 'w', closefd=False), encoding='utf-8', write_through=True)\n"
"    except Exception:\n"
"        pass\n"
"    try:\n"
"        runpy.run_path(path, run_name='__main__')\n"
"        return 0\n"
"    except SystemExit as e:\n"
"        c = e.code\n"
"        if c is None: return 0\n"
"        if isinstance(c, int): return c\n"
"        print(c, file=sys.stderr)\n"
"        return 1\n"
"    except BaseException:\n"
"        traceback.print_exc()\n"
"        return 1\n"
"    finally:\n"
"        try:\n"
"            sys.stdout.flush(); sys.stderr.flush()\n"
"        except Exception:\n"
"            pass\n";

static NSString *PyStatusMessage(PyStatus st) {
    if (st.err_msg) return [NSString stringWithUTF8String:st.err_msg];
    return @"lỗi không rõ";
}

static BOOL AppendPath(PyConfig *cfg, NSString *path) {
    wchar_t *w = Py_DecodeLocale(path.fileSystemRepresentation, NULL);
    if (!w) return NO;
    PyStatus st = PyWideStringList_Append(&cfg->module_search_paths, w);
    PyMem_RawFree(w);
    return !PyStatus_Exception(st);
}

static BOOL InitPython(void) {
    if (gInitialized) return YES;
    if (gInitError) return NO;

    NSString *home = [[NSBundle mainBundle].resourcePath stringByAppendingPathComponent:@"python"];
    NSString *lib = [home stringByAppendingPathComponent:@"lib"];
    NSString *libdir = nil;
    for (NSString *n in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:lib error:nil] ?: @[]) {
        if ([n hasPrefix:@"python3."]) { libdir = [lib stringByAppendingPathComponent:n]; break; }
    }
    if (!libdir) {
        gInitError = [NSString stringWithFormat:@"Không thấy thư viện chuẩn Python trong %@ (IPA build thiếu bước embed_python).", home];
        return NO;
    }

    PyPreConfig pre;
    PyPreConfig_InitIsolatedConfig(&pre);
    pre.utf8_mode = 1;
    PyStatus st = Py_PreInitialize(&pre);
    if (PyStatus_Exception(st)) { gInitError = [@"Py_PreInitialize: " stringByAppendingString:PyStatusMessage(st)]; return NO; }

    PyConfig cfg;
    PyConfig_InitIsolatedConfig(&cfg);
    cfg.buffered_stdio = 0;
    cfg.write_bytecode = 0;
    cfg.install_signal_handlers = 0;
    // (CPython 3.13 chưa có cfg.use_system_logger; stdout/stderr được nối lại vào fd 1/2 ở _catnip_run.)
    st = PyConfig_SetBytesString(&cfg, &cfg.home, home.fileSystemRepresentation);
    if (PyStatus_Exception(st)) { gInitError = [@"home: " stringByAppendingString:PyStatusMessage(st)]; PyConfig_Clear(&cfg); return NO; }
    cfg.module_search_paths_set = 1;
    AppendPath(&cfg, libdir);
    AppendPath(&cfg, [libdir stringByAppendingPathComponent:@"lib-dynload"]);
    AppendPath(&cfg, [libdir stringByAppendingPathComponent:@"site-packages"]);

    st = Py_InitializeFromConfig(&cfg);
    PyConfig_Clear(&cfg);
    if (PyStatus_Exception(st)) { gInitError = [@"Py_InitializeFromConfig: " stringByAppendingString:PyStatusMessage(st)]; return NO; }

    if (PyRun_SimpleString(kPrelude) != 0) { gInitError = @"Không nạp được mã khởi động Python."; return NO; }
    PyEval_SaveThread();                  // nhả GIL; các lần chạy sau dùng PyGILState_Ensure
    gInitialized = YES;
    return YES;
}
#endif

@implementation CatnipPython

+ (BOOL)isAvailable {
#ifdef CATNIP_HAS_PYTHON
    return YES;
#else
    return NO;
#endif
}

+ (int)runScript:(NSString *)path directory:(NSString *)directory error:(NSString **)error {
#ifdef CATNIP_HAS_PYTHON
    if (!InitPython()) {
        if (error) *error = gInitError ?: @"Không khởi tạo được Python.";
        return -1;
    }
    PyGILState_STATE gil = PyGILState_Ensure();
    int code = 1;
    PyObject *main = PyImport_AddModule("__main__");          // mượn tham chiếu
    PyObject *dict = main ? PyModule_GetDict(main) : NULL;
    PyObject *fn = dict ? PyDict_GetItemString(dict, "_catnip_run") : NULL;
    if (!fn) {
        if (error) *error = @"Thiếu hàm khởi động _catnip_run.";
        PyGILState_Release(gil);
        return -1;
    }
    PyObject *res = PyObject_CallFunction(fn, "ss", path.fileSystemRepresentation, directory.fileSystemRepresentation);
    if (res) {
        code = (int)PyLong_AsLong(res);
        Py_DECREF(res);
    } else {
        PyErr_Print();
    }
    PyGILState_Release(gil);
    return code;
#else
    if (error) *error = @"Bản build này không nhúng CPython (bật with_python khi chạy workflow).";
    return -1;
#endif
}

@end
