/* */

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "arrayhash.h"

#define KHARON_DECL	static inline

KHARON_DECL int
encode_get_type(void *data)
{
	SV	*in = data;

	D(fprintf(stderr, "get_type = %p\n", in));

	if (!SvOK(in))
		return STATE_UNDEF;

	if (SvROK(in)) {
		switch (SvTYPE(SvRV(in))) {
		case SVt_PVAV:	return STATE_LIST;
		case SVt_PVHV:	return STATE_MAP;

		/* XXXrcd: memory leaks, likely... */
		case SVt_IV:	croak("Trying to encode SVt_IV");
		case SVt_NV:	croak("Trying to encode SVt_NV");
		case SVt_PV:	croak("Trying to encode SVt_PV");
//		case SVt_RV:	croak("Trying to encode SVt_RV");
		case SVt_PVCV:	croak("Trying to encode SVt_PVCV");
		case SVt_PVGV:	croak("Trying to encode SVt_PVGV");
		case SVt_PVMG:	croak("Trying to encode SVt_PVMG");

		default:
			croak("Encode error: bad data type");
		}
	}

	return STATE_SCALAR;
}

KHARON_DECL char *
encode_get_scalar(void *data, size_t *len)
{
	SV	*in = data;
	char	*ret;
	STRLEN	 l;

	ret = SvPV(in, l);
	*len = l;
	return ret;
}

struct enc_list_iter {
	AV	*av;
	int	 i;
};

KHARON_DECL void *
encode_list_iter(void *data)
{
	struct enc_list_iter	*list;
	SV			*in = data;

	/* XXXrcd: how do we free this? */
	list = malloc(sizeof(*list));
	if (list) {
		list->av = (AV*) SvRV(in);
		list->i  = 0;
	}

	D(fprintf(stderr, "list_iter(%d) = %p\n", list->i, list));
	return list;
}

KHARON_DECL void *
encode_list_next(void *data)
{
	struct enc_list_iter	 *list = data;
	SV			**ret;

	if (list->i > av_len(list->av))
		return NULL;

	ret = av_fetch(list->av, list->i, 0);
	D(fprintf(stderr, "list_next(%d) = %p pointing to %p\n", list->i,
	    ret, *ret));

	list->i++;
	return *ret;
}

KHARON_DECL void
encode_list_free(void *data)
{

	free(data);
}

KHARON_DECL void *
encode_map_iter(void *data)
{
	SV	*in = data;
	HV	*hv;

	D(fprintf(stderr, "map_iter = %p\n", in));
	hv = (HV *)SvRV(in);
	hv_iterinit(hv);

	return hv;
}

KHARON_DECL int
encode_map_next(void *data, void **key, void **val)
{
	HV	*in = data;
	HE	*elem;

	elem = hv_iternext(in);
	if (!elem)
		return 0;

	*key = hv_iterkeysv(elem);
	*val = hv_iterval(in, elem);

	D(fprintf(stderr, "map_next = (key = %p, val = %p)\n", *key, *val));
	return 1;
}

KHARON_DECL void
encode_map_free(void *data)
{

	/* Nothing for Perl. */
}

KHARON_DECL void
string_begin(ssp_val *ret)
{

	*ret = NULL;
	D(fprintf(stderr, "string_begin(%p)\n", *ret));
}

KHARON_DECL void
string_append(ssp_val *ret, const char *str, int len)
{

	if (!*ret) {
		*ret = newSVpvn(str, len);
		D(fprintf(stderr, "string_append(%p): '%s', %d\n", *ret,
		    str, len));
		return;
	}

	sv_catpvn(*ret, str, len);
	D(fprintf(stderr, "string_append(%p): '%s', %d\n", *ret,
	    str, len));
}

KHARON_DECL void
string_end(ssp_val *ret)
{
	char buf[] = "";

	if (!*ret) {
		*ret = newSVpvn(buf, 0);
	}

	D(fprintf(stderr, "string_end(%p)\n", *ret));
}

#define string_free(x)	kharon_perl_free(x)
#define list_free(x)	kharon_perl_free(x)
#define map_free(x)	kharon_perl_free(x)

KHARON_DECL void
kharon_perl_free(ssp_val *ret)
{

	D(fprintf(stderr, "decrementing ref count on %p\n", *ret));
	SvREFCNT_dec(*ret);
}

KHARON_DECL void
undef_begin(ssp_val *ret)
{

	*ret = newSV(0);
	D(fprintf(stderr, "undef_begin(%p):\n", *ret));
}

KHARON_DECL void
list_begin(ssp_val *ret)
{

	*ret = newAV();
	D(fprintf(stderr, "list_begin(%p)\n", *ret));
}

KHARON_DECL void
list_element(ssp_val *ret, ssp_val *elem)
{

	av_push(*ret, *elem);
	D(fprintf(stderr, "list_element(%p, %p)\n", *ret, *elem));
}

KHARON_DECL void
list_end(ssp_val *ret)
{

	D(fprintf(stderr, "list_end(%p) = ", *ret));
	*ret = newRV_noinc(*ret);
	D(fprintf(stderr, "%p\n", *ret));
}

KHARON_DECL void
map_begin(ssp_val *ret)
{

	*ret = newHV();
	D(fprintf(stderr, "map_begin(%p)\n", *ret));
}

KHARON_DECL void
map_element(ssp_val *ret, ssp_val *key, ssp_val *val)
{

	if (!val)
		(void) hv_store_ent((HV *)*ret, (SV *)*key, newSV(0), 0);
	else
		(void) hv_store_ent((HV *)*ret, (SV *)*key, (SV *)*val, 0);

	D(fprintf(stderr, "map_element(%p, %p, %p)\n", *ret, *key,
	    val?*val:0));
}

KHARON_DECL void
map_end(ssp_val *ret)
{

	D(fprintf(stderr, "map_end(%p) = ", *ret));
	*ret = newRV_noinc(*ret);
	D(fprintf(stderr, "%p\n", *ret));
}
