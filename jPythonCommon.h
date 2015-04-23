#ifndef __JPYTHONCOMMON_H__
#define __JPYTHONCOMMON_H__ 1

#include <Python.h>
#include "numpy/arrayobject.h"

void RequireObjectType(PyObject *obj, PyTypeObject &type);
bool ObjectIsNone(PyObject *obj);

#include "jPythonList.h"
#include "jPythonArray.h"

#endif
