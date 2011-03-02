/* $Id: utils.pm,v 1.22 2009/10/27 15:23:32 dowdes Exp $ */

// #define DEBUG 1
#if DEBUG
#define D(x)	do { if (DEBUG) x; } while (0)
#else
#define D(x)
#endif

#include <sys/types.h>
#include <sys/stat.h>

#include <fcntl.h>
#include <malloc.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "parse.h"

/* -------------------------------------------------------------------- */
/* These functions should be provided by the particular binding
 * language rather than being here:
 */

int
get_type(void *data)
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

char *
get_scalar(void *data, int *len)
{
	SV	*in = data;
	char	*ret;
	STRLEN	 l;

	ret = SvPV(in, l);
	*len = l;
	return ret;
}

struct list_iter {
	AV	*av;
	int	 i;
};

void *
list_iter(void *data)
{
	struct list_iter	*list;
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

void *
list_next(void *data)
{
	struct list_iter	 *list = data;
	SV			**ret;

	if (list->i > av_len(list->av))
		return NULL;

	ret = av_fetch(list->av, list->i, 0);
	D(fprintf(stderr, "list_next(%d) = %p pointing to %p\n", list->i,
	    ret, *ret));

	list->i++;
	return *ret;
}

void
list_free(void *data)
{

	free(data);
}

void *
map_iter(void *data)
{
	SV	*in = data;
	HV	*hv;

	D(fprintf(stderr, "map_iter = %p\n", in));
	hv = (HV *)SvRV(in);
	hv_iterinit(hv);

	return hv;
}

int
map_next(void *data, void **key, void **val)
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

void
map_free(void *data)
{

	/* Nothing for Perl. */
}

/* -------------------------------------------------------------------- */

struct {
	int	val;
	char	chr;
} context[] = {
	{ CTX_LEFTBRACE,	'{' },
	{ CTX_RIGHTBRACE,	'}' },
	{ CTX_LEFTBRACKET,	'[' },
	{ CTX_RIGHTBRACKET,	']' },
	{ CTX_COMMA,		',' },
	{ CTX_EQUALS,		'=' },
	{ CTX_BANG,		'!' },
	{ CTX_AND,		'&' },
	{ CTX_SPACE,		' ' },
	{ CTX_BACKSLASH,	'\\' },
	{ 0, 0 }
};

struct enc_entry {
	int			 state;
	int			 first;
	int			 pos;
	void			*data;
	struct encode_state	*prev;
};

ST_DECLARE(struct encode_state, struct enc_entry);

void
encode_push(struct encode_state **st, int state, void *data)
{

	D(fprintf(stderr, "encode_push, enter\n"));
	ST_PUSH(st);
	ST_ENTRY(st).state  = state;
	ST_ENTRY(st).first  = 1;
	ST_ENTRY(st).pos    = 0;
	ST_ENTRY(st).data   = data;
}

void
encode_pop(struct encode_state **st)
{

	D(fprintf(stderr, "encode_pop, enter\n"));
	ST_POP(st);
}

void
encode_undef(struct encode_state **st, char *ret, int *pos, int len)
{

	D(fprintf(stderr, "encode_undef, enter\n"));
	ret[(*pos)++] = '!';
	encode_pop(st);
}

void
encode_list(struct encode_state **st, char *ret, int *pos, int len)
{
	void	*tmp;
	int	 ctx;

	D(fprintf(stderr, "encode_list, enter state = 0x%x\n",
	    ST_ENTRY(st).state));
	if (ST_ENTRY(st).first) {
		if ((ST_ENTRY(st).state & STATE_BITMASK) != STATE_SPLIST)
			ret[(*pos)++] = '[';
		ST_ENTRY(st).data = list_iter(ST_ENTRY(st).data);

		if (!ST_ENTRY(st).data) {
			/* XXXrcd: failure! */
		}
	}

	tmp = list_next(ST_ENTRY(st).data);

	if (!tmp) {
		list_free(ST_ENTRY(st).data);
		if ((ST_ENTRY(st).state & STATE_BITMASK) != STATE_SPLIST) {
			ST_ENTRY(st).state = STATE_CHAR;
			ST_ENTRY(st).data  = (void *) ']';
		} else {
			/* XXXrcd: suspect logic: */
			encode_pop(st);
		}
		return;
	}

	if (!ST_ENTRY(st).first) {
		if ((ST_ENTRY(st).state & STATE_BITMASK) != STATE_SPLIST)
			ret[(*pos)++] = ',';
		else
			ret[(*pos)++] = ' ';
	}

	if ((ST_ENTRY(st).state & STATE_BITMASK) == STATE_SPLIST)
		ctx = CTX_SPACE;
	else
		ctx = CTX_COMMA;

	ST_ENTRY(st).first = 0;
	encode_push(st, STATE_VAR | ctx|CTX_RIGHTBRACKET, tmp);
}

void
encode_map(struct encode_state **st, char *ret, int *pos, int len)
{
	void	*key;
	void	*val;
	int	 first = ST_ENTRY(st).first;

	D(fprintf(stderr, "encode_map, enter\n"));
	if (first) {
		ret[(*pos)++] = '{';
		ST_ENTRY(st).first = 0;
		ST_ENTRY(st).data = map_iter(ST_ENTRY(st).data);
	}

	if (!map_next(ST_ENTRY(st).data, &key, &val)) {
		ST_ENTRY(st).state = STATE_CHAR;
		ST_ENTRY(st).data  = (void *) '}';
		return;
	}

	encode_push(st, STATE_VAR|CTX_COMMA|CTX_RIGHTBRACE|CTX_EQUALS, val);
	encode_push(st, STATE_CHAR, '=');
	encode_push(st, STATE_SCALAR|CTX_COMMA|CTX_RIGHTBRACE|CTX_EQUALS, key);
	if (!first)
		encode_push(st, STATE_CHAR, ',');

}

void
encode_char(struct encode_state **st, char *ret, int *pos, int len)
{

	D(fprintf(stderr, "encode_char, enter\n"));
	ret[(*pos)++] = (char) ST_ENTRY(st).data;
	encode_pop(st);
}

void
encode_var(struct encode_state **st, char *ret, int *pos, int len)
{

	D(fprintf(stderr, "encode_var, enter\n"));
	ST_ENTRY(st).state &= ~STATE_BITMASK;
	ST_ENTRY(st).state |= get_type(ST_ENTRY(st).data);
}

void
encode_scalar(struct encode_state **st, char *ret, int *pos, int len)
{
	unsigned char	*str;
	int		 ctx;
	int		 strlen;
	int		 i;
	int		 intercharpos;

	D(fprintf(stderr, "encode_scalar, enter\n"));
	str = get_scalar(ST_ENTRY(st).data, &strlen);

	if (strlen == 0) {
		ret[(*pos)++] = '\\';
		ST_ENTRY(st).state = STATE_CHAR;
		ST_ENTRY(st).data  = (void *) 'z';
		return;
	}

	ctx = ST_ENTRY(st).state & STATE_CTXMASK;
	ctx |= CTX_BACKSLASH;

	for (i=ST_ENTRY(st).pos; i < strlen && (*pos) < len; ) {
		int	tmpctx = ctx;
		int	ctxptr = 0;
		int	quote  = 0;
		char	tmpchar;

		D(fprintf(stderr, "encode_scalar, enter: pos=%d len=%d\n",
		    i, strlen));

		intercharpos = STATE_REMAINS & ST_ENTRY(st).state;

		if (ST_ENTRY(st).first) {
			tmpctx |= 0xffff;
			ST_ENTRY(st).first = 0;
		}

		if (str[i] < 32 || str[i] > 126) {
			switch (intercharpos) {
			case 0:
				tmpchar = '\\';
				intercharpos++;
				break;
			case 1:
				tmpchar = '0' + (str[i] >> 4);
				intercharpos++;
				break;
			case 2:
				tmpchar = '0' + (str[i] & 0x0f);
				intercharpos = 0;
				i++;
				break;
			}

			if (tmpchar != '\\' && tmpchar > '9')
				tmpchar += 'a' - '9' - 1;

			ret[(*pos)++] = tmpchar;
			ST_ENTRY(st).state &= ~STATE_REMAINS;
			ST_ENTRY(st).state |= intercharpos;
			continue;
		}

		if (intercharpos) {
			ret[(*pos)++] = str[i++];
			ST_ENTRY(st).state &= ~STATE_REMAINS;
			continue;
		}

		for (ctxptr=0; tmpctx && context[ctxptr].val; ctxptr++) {
			if (tmpctx & context[ctxptr].val) {
				if (str[i] == context[ctxptr].chr) {
					tmpctx = 0;
					quote = 1;
				} else {
					tmpctx &= ~context[ctxptr].val;
				}
			}
		}

		if (quote) {
			ret[(*pos)++] = '\\';
			ST_ENTRY(st).state &= ~STATE_REMAINS;
			ST_ENTRY(st).state |= 1;
		} else {
			ret[(*pos)++] = str[i++];
		}
	}

	ST_ENTRY(st).pos = i;
	if (i >= strlen)
		encode_pop(st);
}

struct encode_state *
marshall_init(void *data)
{
	struct encode_state *the_st = NULL, **st = &the_st;

	encode_push(st, STATE_SPLIST, data);
	return the_st;
}

struct encode_state *
encode_init(void *data, int ctx)
{
	struct encode_state *the_st = NULL, **st = &the_st;

	encode_push(st, STATE_VAR | ctx, data);
	return the_st;
}

int
encode(struct encode_state **st, char *ret, int len)
{
	int	 pos;

	D(fprintf(stderr, "encode, enter\n"));
	for (pos=0; pos < len;) {
		D(fprintf(stderr, "encode, loop pos=%d\n", pos));
		D(fprintf(stderr, "encode, loop ret=%.*s\n", pos, ret));

		switch (ST_ENTRY(st).state & STATE_BITMASK) {
		case STATE_VAR:	     encode_var(st, ret, &pos, len);    break;
		case STATE_CHAR:     encode_char(st, ret, &pos, len);   break;
		case STATE_UNDEF:    encode_undef(st, ret, &pos, len);  break;
		case STATE_SPLIST:   encode_list(st, ret, &pos, len);   break;
		case STATE_LIST:     encode_list(st, ret, &pos, len);   break;
		case STATE_MAP:	     encode_map(st, ret, &pos, len);    break;
		case STATE_SCALAR:   encode_scalar(st, ret, &pos, len); break;
		}

		if (ST_IS_EMPTY(st))
			break;
	}

	return pos;
}

void
encode_free(struct encode_state **st)
{

	/* XXXrcd: !!! */
}
