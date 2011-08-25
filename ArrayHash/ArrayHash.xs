#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <stdio.h>

#include "arrayhash.h"
#include "arrayhash_perl.c"
#include "arrayhash.c"

typedef struct self ArrayHash;

MODULE = Kharon::Protocol::ArrayHash  PACKAGE = Kharon::Protocol::ArrayHash

PROTOTYPES: ENABLE

ArrayHash *
new(class, ...)
	SV	*class
 INIT:
        ArrayHash	*self;
	int		 i;
	char		*key;
	STRLEN		 len;
 CODE:
	if (!class) /* XXXrcd: for -Wall must use class */
		croak("NULL passed in.");

	self = parse_init();
	for (i=0; i*2+1 < items; i++) {
		key = SvPV(ST(1+i*2), len);
		if (len != strlen("banner"))
			croak("hash contains unrecognised argument (len)");
		if (strncmp(key, "banner", strlen("banner")))
			croak("hash contains unrecognised argument (key)");
		self->banner = newSVsv(ST(1+i*2+1));
	}
        RETVAL = self;
 OUTPUT:
        RETVAL

MODULE = Kharon::Protocol::ArrayHash  PACKAGE = ArrayHashPtr PREFIX = ArrayHash_

void
ArrayHash_DESTROY(self)
        ArrayHash *self
 CODE:
        parse_free(self);

SV *
ArrayHash_SendBanner(self)
	ArrayHash *self
 CODE:
	/* XXXrcd: hmmm, need to do better than this... */
	SvREFCNT_inc(self->banner);
	RETVAL = self->banner;
 OUTPUT:
	RETVAL

int
ArrayHash_bannerMatches(self, banner)
	ArrayHash	*self
	SV		*banner
 CODE:
	/* XXXrcd: hmmm, do a comparison? */
	if (banner)
		RETVAL = 1;
	else
		RETVAL = 0;
 OUTPUT:
	RETVAL

int
ArrayHash_append(self, input)
	ArrayHash	*self
	SV		*input
 INIT:
	char	*in;
	STRLEN	 len;
 CODE:
	in = SvPV(input, len);
	if (!in)
		croak("append method requires a defined scalar");
	RETVAL = parse_append(self, in, len);
 OUTPUT:
	RETVAL

void
ArrayHash_Reset(self)
	ArrayHash	*self
CODE:
	// fprintf(stderr, "Reset xs entry\n");
	parse_reset(self);

SV *
ArrayHash_Encode(self, code, ...)
	ArrayHash	*self
	int		 code
 INIT:
        char			 buf[8192];
	int			 i;
	size_t			 len;
	struct encode_state	*st;
	SV			*ret;
 CODE:
	/* XXXrcd: this encodes over itself, just testing */
	ret = newSVpvn(buf, 0);
	for (i=2; i < items; i++) {
		st = encode_init(ST(i), CTX_SPACE);
		snprintf(buf, sizeof(buf), "%03d %c ", code,
		    i==(items-1)?'.':'-');
		sv_catpvn(ret, buf, (STRLEN) strlen(buf));
		for (;;) {
			len = encode(&st, buf, sizeof(buf));
			sv_catpvn(ret, buf, (STRLEN) len);
			if (len < sizeof(buf))
				break;
		}
		snprintf(buf, sizeof(buf), "\r\n");
		sv_catpvn(ret, buf, (STRLEN) strlen(buf));
	}
        RETVAL = ret;
 OUTPUT:
        RETVAL

SV *
ArrayHash_Encode_Error(self, code, errstr)
	ArrayHash	*self
	int		 code
	SV		*errstr
 INIT:
        char			 buf[8192];
	size_t			 len;
	struct encode_state	*st;
	SV			*ret;
 CODE:
	/* XXXrcd: this encodes over itself, just testing */
	ret = newSVpvn(buf, 0);
	st = encode_init(errstr, CTX_COMMA|CTX_RIGHTBRACE|CTX_EQUALS);
	snprintf(buf, sizeof(buf), "%03d . {errstr=", code);
	sv_catpvn(ret, buf, (STRLEN) strlen(buf));
	for (;;) {
		len = encode(&st, buf, sizeof(buf));
		sv_catpvn(ret, buf, (STRLEN) len);
		if (len < sizeof(buf))
			break;
	}
	snprintf(buf, sizeof(buf), "}\r\n");
	sv_catpvn(ret, buf, (STRLEN) strlen(buf));
        RETVAL = ret;
 OUTPUT:
        RETVAL

SV *
ArrayHash_Marshall(self, cmd)
	ArrayHash	*self
	SV		*cmd
 INIT:
	struct encode_state	*st;
        char			 buf[8192];
	size_t			 len;
	SV			*ret;
 CODE:
	ret = newSVpvn(buf, 0);
	st = marshall_init(cmd);
	for (;;) {
		len = encode(&st, buf, sizeof(buf));
		sv_catpvn(ret, buf, (STRLEN) len);
		if (len < sizeof(buf))
			break;
	}
	sv_catpvn(ret, "\n", 1);
	RETVAL = ret;
 OUTPUT:
	RETVAL

SV *
ArrayHash_Unmarshall(self, line)
	ArrayHash	*self
	char		*line
 CODE:
	/* XXXrcd: line should not be a char... */
	unmarshall(self, line, strlen(line));
	if (!self->done)
		croak("Parsing is not complete");
	if (!self->results)
		croak("No results are available, yet");
	RETVAL = *self->results;
	*self->results = NULL;
 OUTPUT:
	RETVAL

SV *
ArrayHash_Parse(self)
        ArrayHash	*self
 PPCODE:  
//	fprintf(stderr, "self = %p\n", self);
//	fprintf(stderr, "self->code     = %d\n", self->code);
//	fprintf(stderr, "self->st       = %p\n", self->st);
//	fprintf(stderr, "self->results  = %p\n", self->results);
//	fprintf(stderr, "*self->results = %p\n", *self->results);
	if (!self->done)
		croak("Parsing is not complete");
	if (!self->results)
		croak("No results are available, yet");
	EXTEND(SP, 2);
	PUSHs(sv_2mortal(newSViv(self->code)));
	PUSHs(sv_2mortal(*self->results));
	*self->results = NULL;
	RETVAL = NULL;	/* make -Wall quiet */

