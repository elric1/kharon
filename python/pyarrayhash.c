#include <arrayhash.h>
#include "arrayhash_python.c"
#include <arrayhash.c>

#define PY_SSIZE_T_CLEAN

#include <Python.h>

#define MAX_ENCODED 16384

void
pyarrayhash_delete(PyObject *parser)
{
    struct self *pstate = PyCapsule_GetPointer(parser, NULL);
    parse_free(pstate);
}

static PyObject *
pyarrayhash_parse_init(PyObject *klass, PyObject *args)
{
    struct self *pstate = parse_init();
    if (pstate == NULL) {
        return PyErr_NoMemory();
    }
    parse_reset(pstate);
    return Py_BuildValue("O", PyCapsule_New(pstate, NULL, &pyarrayhash_delete));
}

static PyObject *
pyarrayhash_parse_state(PyObject *klass, PyObject *args)
{
    PyObject *parser;

    if(!PyArg_ParseTuple(args, "O", &parser))
        return NULL;

    struct self *pstate = PyCapsule_GetPointer(parser, NULL);

    if (pstate != NULL) {
        return Py_BuildValue("(iii)", pstate->done, pstate->code, pstate->st);
    } else {
        return NULL;
    }
}

static PyObject *
pyarrayhash_parse_append(PyObject *klass, PyObject *args)
{
    PyObject *parser;
    char *buffer;
    Py_ssize_t buffer_len;

    if(!PyArg_ParseTuple(args, "Os#", &parser, &buffer, &buffer_len))
        return NULL;

    struct self *pstate = PyCapsule_GetPointer(parser, NULL);

    if (pstate == NULL) {
        return NULL;
    }

    int err;
    err = parse_append(pstate, buffer, buffer_len);

    if (!err) {
        return *pstate->results;
    }

    Py_RETURN_NONE;
}

static PyObject *
pyarrayhash_encode(PyObject *klass, PyObject *args)
{
    PyObject *o;

    if (!PyArg_ParseTuple(args, "O", &o))
        return NULL;

    char *encoded_buffer;
    encoded_buffer = malloc(MAX_ENCODED);
    if (encoded_buffer == NULL) {
        return PyErr_NoMemory();
    }

    struct encode_state *encoder;
    encoder = marshall_init(o);
    if (encoder == NULL) {
        free(encoded_buffer);
        return PyErr_NoMemory();
    }

    int szout;
    szout = encode(&encoder, encoded_buffer, MAX_ENCODED);
    o =  PyString_FromStringAndSize(encoded_buffer, szout);
    encode_free(&encoder);
    free(encoded_buffer);

    return o;
}

static PyMethodDef PyArrayHashMethods[] = {
    { "parse", pyarrayhash_parse_append, METH_VARARGS, "Parse some t kharon perl hash" },
    { "parse_init", pyarrayhash_parse_init, METH_VARARGS, "Initialize a perl hash parser" },
    { "parser_state", pyarrayhash_parse_state, METH_VARARGS, "Return a tuple (done, code, st) from the arrayhash parser" },
    { "encode", pyarrayhash_encode, METH_VARARGS, "Enocde some of that kharon perl hash stuff" },
    { NULL, NULL, 0, NULL }
};


PyMODINIT_FUNC initpyarrayhash(void){
    PyObject *m;
    m = Py_InitModule3("pyarrayhash", PyArrayHashMethods, "Wrap the parser for kharon");
}




