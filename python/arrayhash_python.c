#include "Python.h"

#include "arrayhash.h"

#define KHARON_DECL	static inline

// TODO FIXME The ArrayHash API doesn't currently support anyway to signal failure in encoding
//            to the upper layers. When it does support signalling, fix this.
//            Places that need error handling are all the Py_Get* functions, they can all return NULL
//            Also the Py_*Next Calls

struct enc_list_iter {
    PyObject *iterable;
    Py_ssize_t i;
};

KHARON_DECL int
encode_get_type(void *data)
{
    PyObject *o = data;

    if (PyDict_Check(o)) {
        return STATE_MAP;
    } else if (PyList_Check(o)) {
        return STATE_LIST;
    } else {
        return STATE_SCALAR; // Would be nice to be able to encode more types
    }
}

KHARON_DECL char *
encode_get_scalar(void *data, int *len)
{
    char *ret;
    PyObject *m = data;
    PyObject *s;

    // str(m)
    // This really should never fail, but the API docs
    // allow for the possibility
    s = PyObject_Str(m);
    if (s != NULL) {
        /* It might not be readily apparent why this (Not calling INCREF and
           passing the internal string) is safe. We send the string up to the caller,
           who is then going to immediately serialize it to a buffer. This all
           happens inside of a call where the Python GC can't free it. This is
           probably obvious to everyone else, but I have to think about it each time
           through this function.
        */
        ret = PyString_AsString(s);
        if (ret == NULL) {
            *len = 0;
            return NULL;
        }
        *len = strlen(ret);
    } else {
        ret = NULL;
        *len = 0;
    }

    D(fprintf(stderr, "encode_get_scalar = %s %d", ret, *len));
    return ret;
}

KHARON_DECL void *
encode_list_iter(void *data)
{
    // TODO FIXME The ArrayHash API doesn't currently support anyway to signal failure in encoding
    //            to the upper layers. When it does support signalling, fix this.
    struct enc_list_iter *iter = malloc(sizeof(*iter));
    iter->iterable = data;
    iter->i = 0;
    D(fprintf(stderr, "list_iter(%zu) = %p\n", iter->i, iter));
    return iter;
}

KHARON_DECL void *
encode_list_next(void *data)
{
    struct enc_list_iter *list = data;
    PyObject *m = list->iterable;

    if (list->i < PyList_Size(m)) {
        PyObject *v = PyList_GetItem(m, list->i);
        list->i++;
        return v;
    }

    return NULL;
}


KHARON_DECL void
encode_list_free(void *data)
{
    free(data);
}

KHARON_DECL void *
encode_map_iter(void *data)
{
    struct enc_list_iter *iter = malloc(sizeof(*iter));
    iter->iterable=data;
    iter->i = 0;
    return (void *)iter;
}

KHARON_DECL int
encode_map_next(void *data, void **key, void **val)
{
    PyObject *k, *v;
    PyObject *dict = ((struct enc_list_iter *)data)->iterable;
    Py_ssize_t *i = &(((struct enc_list_iter *)data)->i);

    int ret = PyDict_Next(dict, i, &k, &v);
    *key = k;
    *val = v;
    D(fprintf(stderr, "map_next = (key = %p, val = %p)\n", *key, *val));
    return ret;
}

KHARON_DECL void
encode_map_free(void *data)
{
    free(data);
}

KHARON_DECL void
string_begin(ssp_val *ret)
{
    *ret = NULL;
    D(fprintf(stderr, "string_begin(%p)\n", *ret));
}

KHARON_DECL void
string_append(ssp_val *ret, const char *str, const Py_ssize_t len)
{
    if (!*ret) {
        *ret = PyString_FromStringAndSize(str, len);

        D(fprintf(stderr, "a string_append_empty(%p): %d ::'%s', %d\n", *ret, ((PyObject *) *ret )->ob_refcnt,
                str, len));
        return;
    } else {
        PyObject *next = PyString_FromStringAndSize(str, len);
        if (next != NULL) {
            PyString_ConcatAndDel((PyObject **) ret, next);
        }
        D(fprintf(stderr, "string_append(%p): %d :: '%s', %d %d\n", *ret,((PyObject *) *ret )->ob_refcnt,
                str, len ));
    }

}

KHARON_DECL void
string_end(ssp_val *ret)
{
    D(fprintf(stderr, "string_end(%p) rcount: %d\n", *ret, ((PyObject *)*ret)->ob_refcnt));
}

#define string_free(x) kharon_python_free(x)
#define list_free(x) kharon_python_free(x)
#define map_free(x) kharon_python_free(x)

KHARON_DECL void
kharon_python_free(ssp_val *ret)
{
    D(fprintf(stderr, "\ndecrementing ref count on %p\n", *ret));
    Py_DECREF(*ret);
}

KHARON_DECL void
undef_begin(ssp_val *ret)
{
    Py_INCREF(Py_None);
    *ret = Py_None;
    D(fprintf(stderr, "undef_begin(%p):\n", *ret));
}

KHARON_DECL void
list_begin(ssp_val *ret)
{
    *ret = (ssp_val *) PyList_New(0);
    D(fprintf(stderr, "list_begin(%p)\n", *ret));
}

KHARON_DECL void
list_element(ssp_val *ret, ssp_val *elem)
{
    PyObject *list = *ret;
    D(fprintf(stderr, "is_list:%d\n", PyList_Check(list)));

    PyList_Append(list, *elem);
    Py_DECREF(*elem);
    D(fprintf(stderr, "list_element(%p) counts: %d\n = ", *elem, ((PyObject *)*elem)->ob_refcnt));
}

KHARON_DECL void
list_end(ssp_val *ret)
{
    D(fprintf(stderr, "list_end(%p) counts: %d\n = ", *ret, list->ob_refcnt));
    D(fprintf(stderr, "%p %d\n", *ret , PyList_Size((PyObject *)*ret)));
}

KHARON_DECL void
map_begin(ssp_val *ret)
{
    *ret = PyDict_New();
    D(fprintf(stderr, "map_begin(%p) counts: %d\n", *ret, ((PyObject *) *ret)->ob_refcnt));
}

KHARON_DECL void
map_element(ssp_val *ret, ssp_val *key, ssp_val *val)
{
    PyObject *dict = *ret;
    D(fprintf(stderr, "is_dict: %d\n", PyDict_Check(dict)));

    if (val == NULL) {
        PyDict_SetItem(dict, *key, Py_None);
        Py_DECREF(*key);
    } else {
        PyDict_SetItem(dict, *key, *val);
        Py_DECREF(*key);
        Py_DECREF(*val);
    }

    D(fprintf(stderr, "map_element(%p, %p, %p) counts: %d %d %d\n", *ret, *key,
            val?*val:0, dict->ob_refcnt, ((PyObject *) *key)->ob_refcnt, ((PyObject *) *val)->ob_refcnt));
}

KHARON_DECL void
map_end(ssp_val *ret)
{
    D(fprintf(stderr, "map_end(%p) = ", *ret));
    D(fprintf(stderr, "map_end(%p) counts: %d\n", *ret, dict->ob_refcnt));
    D(fprintf(stderr, "%p\n", *ret));
}
