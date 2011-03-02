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

#define USE_PERL5

#ifdef USE_PERL5
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#endif

#include "parse.h"

#define STR_BUF_LEN	1

static inline void
string_begin(ssp_val *ret)
{

	*ret = NULL;
	D(fprintf(stderr, "string_begin(%p)\n", *ret));
}

static inline void
string_append(ssp_val *ret, char *str, int len)
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

static inline void
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

static inline void
kharon_perl_free(ssp_val *ret)
{

	D(fprintf(stderr, "decrementing ref count on %p\n", *ret));
	SvREFCNT_dec(*ret);
}

static inline void
undef_begin(ssp_val *ret)
{

	*ret = newSV(0);
	D(fprintf(stderr, "undef_begin(%p):\n", *ret));
}

static inline void
list_begin(ssp_val *ret)
{

	*ret = newAV();
	D(fprintf(stderr, "list_begin(%p)\n", *ret));
}

static inline void
list_element(ssp_val *ret, ssp_val *elem)
{

	av_push(*ret, *elem);
	D(fprintf(stderr, "list_element(%p, %p)\n", *ret, *elem));
}

static inline void
list_end(ssp_val *ret)
{

	D(fprintf(stderr, "list_end(%p) = ", *ret));
	*ret = newRV_noinc(*ret);
	D(fprintf(stderr, "%p\n", *ret));
}

static inline void
map_begin(ssp_val *ret)
{

	*ret = newHV();
	D(fprintf(stderr, "map_begin(%p)\n", *ret));
}

static inline void
map_element(ssp_val *ret, ssp_val *key, ssp_val *val)
{

	if (!val)
		hv_store_ent((HV *)*ret, (SV *)*key, newSV(0), 0);
	else
		hv_store_ent((HV *)*ret, (SV *)*key, (SV *)*val, 0);

	D(fprintf(stderr, "map_element(%p, %p, %p)\n", *ret, *key,
	    val?*val:0));
}

static inline void
map_end(ssp_val *ret)
{

	D(fprintf(stderr, "map_end(%p) = ", *ret));
	*ret = newRV_noinc(*ret);
	D(fprintf(stderr, "%p\n", *ret));
}


static inline ssp_val *
stack_get_ssp_val(struct stack **st)
{

	return &(ST_ENTRY(st).ret);
}

static inline void
stack_set_ssp_val(struct stack **st, ssp_val ret)
{

	ST_ENTRY(st).ret = ret;
}

static inline int
stack_get_state(struct stack **st)
{

	return ST_ENTRY(st).state & STATE_BITMASK;
}

static inline void
stack_set_state(struct stack **st, int state)
{

	if (state & ~STATE_BITMASK)
		abort();

	ST_ENTRY(st).state &= ~STATE_BITMASK;
	ST_ENTRY(st).state |= state;
}

static inline void
stack_set_flags(struct stack **st, int flags)
{

	ST_ENTRY(st).state |= flags;
}

static inline void
stack_clear_flags(struct stack **st, int flags)
{

	ST_ENTRY(st).state &= ~flags;
}

static inline int
stack_get_flags(struct stack **st)
{

	return ST_ENTRY(st).state & STATE_FLAGMASK;
}

static inline int
stack_get_ctx(struct stack **st)
{

	return ST_ENTRY(st).state;	/* We don't exclude STATE_BITMASK
					 * because we only ever & with the
					 * result and hence it is unnec.
					 */
}

static inline void
stack_add_ctx(struct stack **st, int ctx)
{

	ST_ENTRY(st).state |= ctx;
}

/* XXXrcd: pop needs be rewritten */
static inline void
push(struct stack **st)
{
	struct stack	*new;

	D(fprintf(stderr, "pushing...\n"));
	ST_PUSH(st);
	ST_ENTRY(st).state = 0;
	stack_set_ssp_val(st, NULL);
}

/* XXXrcd: pop needs be rewritten */
static inline void
pop(struct stack **st)
{
	struct stack	*tmp;

	D(fprintf(stderr, "popping(%p) = ", *st));
	ST_POP(st);
	D(fprintf(stderr, "%p\n", *st));
}

static inline int
get_next_lex(struct parse *p)
{
	int		 ret;

	if (!p || !p->pos)
		return BAD;

	if (p->remnant != BAD) {
		ret = p->remnant;
		p->remnant = BAD;
		return ret;
	}

	for (;;) {
		if (p->pos - p->input >= p->inlen)
			return EOL;

		ret = *p->pos;
		p->pos++;

		D(fprintf(stderr, "lexing '%c'\n", ret));

		switch (p->lexstate & 0xf000) {
		case LEX_NORMAL:
			switch (ret) {
			case ' ':	return SPACE;
			case ',':	return COMMA;
			case '!':	return BANG;
			case '&':	return AND;
			case '=':	return EQUALS;
			case '[':	return LEFTBRACKET;
			case ']':	return RIGHTBRACKET;
			case '{':	return LEFTBRACE;
			case '}':	return RIGHTBRACE;
			case '\r': 	p->lexstate = LEX_GOTCR;	break;
			case '\n':	return CRLF;
			case '\\':	p->lexstate = LEX_GOTBACKSLASH;	break;
			default:	if (ret < 32)
						return BAD;
					return ret;
			}
			break;

		case LEX_GOTBACKSLASH:
			p->lexstate = LEX_NORMAL;
			if (ret >= '0' && ret <= '9') {
				p->lexstate = LEX_GOTHEXDIGIT;
				p->lexstate |= (ret - '0') << 4;
			} else if (ret >= 'a' && ret <= 'f') {
				p->lexstate = LEX_GOTHEXDIGIT;
				p->lexstate |= (10 + ret - 'a') << 4;
			} else if (ret >= 'A' && ret <= 'F') {
				p->lexstate = LEX_GOTHEXDIGIT;
				p->lexstate |= (10 + ret - 'A') << 4;
			} else if (ret == 'z') {
				return EMPTY;
			} else {
				return ret;
			}
			break;

		case LEX_GOTHEXDIGIT:
			p->lexstate &= 0x0fff;
			if (ret >= '0' && ret <= '9') {
				ret += p->lexstate - '0';
			} else if (ret >= 'a' && ret <= 'f') {
				ret += p->lexstate + 10 - 'a';
			} else if (ret >= 'A' && ret <= 'F') {
				ret += p->lexstate + 10 - 'A';
			} else {
				return BAD;
			}
			p->lexstate = LEX_NORMAL;
			return ret;

		case LEX_GOTCR:
			if (ret != '\n')
				return BAD;

			p->lexstate = LEX_NORMAL;
			return CRLF;
		}
	}
}

static inline int
state_smtplike(struct self *self, int c)
{
	struct stack	**st = &self->st;
	int		  code;

	code = *(int *)stack_get_ssp_val(st);

D(fprintf(stderr, "state_smtplike code=%d got '%c'\n", code, c));

	if (code < 1000 && c >= '0' && c <= '9') {
		if (code > 999)
			return BAD;

		code *= 10;
		code += c - '0';

		stack_set_ssp_val(st, (ssp_val)code);
		return;
	}

	switch (c) {
	case SPACE:
		if (code < 100) {
fprintf(stderr, "state_smtplike: ERROR 2\n");
			return BAD;
		}

		break;

	case '.':
		if (code < 1000)
			self->done = 1;

	case '-':
		if (code < 100) {
fprintf(stderr, "state_smtplike: ERROR\n");
			return BAD;
		}

		if (code < 1000) {
			code += 1000;
			stack_set_ssp_val(st, (ssp_val)code);
			break;
		}
		/*FALLTHROUGH*/

	default:
		if (code < 1100) {
fprintf(stderr, "state_smtplike: ERROR 3\n");
			return BAD;
		}
		self->p.remnant = c;
		self->code = code - 1000;
//		if (self->code > 0 && code != self->code) {
// fprintf(stderr, "CODEs do not match!\n");
// return BAD;
//		}
		pop(st);
D(fprintf(stderr, "state_stmplike done: code = %d\n", self->code));
		break;

	}
}

/* XXXrcd: huh? why isn't this one necessary?? */
static inline void
state_splist(struct parse *p, struct stack *st, int c)
{

}

static inline int
chr_matches_ctx(struct stack **st, int chr)
{
	int	ctx;

	ctx = stack_get_ctx(st);

#define RET_TRUE_IF(x)	if (ctx & (x)) return 1; break;
	switch (chr) {
	case RIGHTBRACKET:	RET_TRUE_IF(CTX_RIGHTBRACKET);
	case RIGHTBRACE:	RET_TRUE_IF(CTX_RIGHTBRACE);
	case COMMA:		RET_TRUE_IF(CTX_COMMA);
	case EQUALS:		RET_TRUE_IF(CTX_EQUALS);
	case SPACE:		RET_TRUE_IF(CTX_SPACE);
	case CRLF:		RET_TRUE_IF(CTX_CRLF);

	}

	return 0;
}

static inline void
state_var(struct parse *p, struct stack **st, int c)
{
	ssp_val	*s;

// #if 0 /* XXXrcd: ? */
	if (chr_matches_ctx(st, c)) {
		stack_set_flags(st, STATE_DONE);
		p->remnant = c;
		return;
	}
// #endif

	s = stack_get_ssp_val(st);
	switch (c) {
	case BANG:
		undef_begin(s);
		stack_set_state(st, STATE_UNDEF);
		stack_set_flags(st, STATE_DONE);
		break;
	case EMPTY:
		string_begin(s);
		string_end(s);
		stack_set_state(st, STATE_SCALAR);
		stack_set_flags(st, STATE_DONE);
		break;
/* XXXrcd: pop for the prior two? */

	case LEFTBRACKET:
		list_begin(s);
		stack_set_state(st, STATE_LIST);
		stack_set_flags(st, STATE_FIRST);
		push(st);
		stack_set_state(st, STATE_VAR);
		stack_add_ctx(st, CTX_RIGHTBRACKET|CTX_COMMA);
		break;

	case LEFTBRACE:
		map_begin(s);
		stack_set_state(st, STATE_MAP_KEY);
		push(st);
		stack_set_state(st, STATE_SCALAR);
		stack_add_ctx(st, CTX_RIGHTBRACE|CTX_COMMA|CTX_EQUALS);
		break;

	default:
		string_begin(s);
		p->remnant = c;
		stack_set_state(st, STATE_SCALAR);
		break;
	}
}

static inline void
state_scalar(struct parse *p, struct stack **st, int c)
{
	ssp_val		*ret;
	char		 buf[STR_BUF_LEN] = "";
	char		*start;
	int		 i;

	ret = stack_get_ssp_val(st);

	/*
	 * First we deal with all the simple characters quickly as a
	 * single string without copying.  We are hoping that this will
	 * take care of a majority of most strings as they'll likely be
	 * ascii.  XXXrcd: is this useful at all?  Maybe not.
	 */

	if (p->pos > p->input) {
		start = p->pos - 1;
		for (i=0; c == start[i]; i++)
			c = get_next_lex(p);

		if (i > 0) {
			D(fprintf(stderr, "state_scalar: END got: '%s', %d\n",
			    start, i));
			string_append(ret, start, i);
		}
	}

	/* Now for the meat of the function. */

	for (i=0; i < sizeof(buf); i++) {
		if (chr_matches_ctx(st, c) || c == EOL) {
			break;
		}

		if (c < 0)
			c = -c;

		buf[i] = (char) c;
		c = get_next_lex(p);
	}

	if (i > 0) {
		D(fprintf(stderr, "state_scalar: end got: '%*s', %d\n", i,
		    buf, i));
		string_append(ret, buf, i);
	}

	p->remnant = c;

	if (chr_matches_ctx(st, c))
		stack_set_flags(st, STATE_DONE);
}

void
state_done(struct parse *p, struct stack **st, int c)
{
	struct parse	  pars;
	ssp_val		 *ret;
	ssp_val		 *key;
	ssp_val		 *val;
	ssp_val		  tmp;
	int		  state;
	int		  oldstate;

	/*
	 * XXXrcd: Hmmm, I've just removed string_end() from the end of
	 *         state_scalar and need to finish the work!!
	 */

	/* XXXrcd: Hmmm... is val valid when we pop?  maybe not... */
	val      = stack_get_ssp_val(st);
	oldstate = stack_get_state(st);
	pop(st);
	D(fprintf(stderr, "state_done, oldstate = %x\n", oldstate));

	ret   = stack_get_ssp_val(st);
	state = stack_get_state(st);
	D(fprintf(stderr, "state_done, understate = %x\n", state));

	if (!*val && state != STATE_LIST && state != STATE_MAP_KEY)
		string_end(val);

	switch (state & STATE_BITMASK) {
	case STATE_SPLIST:
		list_element(ret, val);

		for (;;) {
			if (c == BAD)
				return;	/* XXXrcd: ERROR??? */

			if (c != SPACE)
				break;

			c = get_next_lex(p);
		}

/* XXXrcd: what's this EOL logic here? */
		if (c != EOL) {
			p->remnant = c;
			push(st);
			stack_set_state(st, STATE_VAR);
			stack_add_ctx(st, CTX_SPACE|CTX_CRLF);
		}
		break;

	case STATE_LIST:
		if (!*val && !((stack_get_flags(st) & STATE_FIRST) &&
		    c == RIGHTBRACKET)) {
			D(fprintf(stderr, "THE THING!\n"));
			string_end(val);
		} else {
			D(fprintf(stderr, "NOT THE THING!\n"));
		}

		if (*val)
			list_element(ret, val);

		stack_clear_flags(st, STATE_FIRST);

		if (c == COMMA) {
			push(st);
			stack_set_state(st, STATE_VAR);
			stack_add_ctx(st, CTX_RIGHTBRACKET|CTX_COMMA);
		}
		if (c == RIGHTBRACKET) {
			list_end(ret);
			stack_set_flags(st, STATE_DONE);
		}
		break;

	case STATE_MAP_KEY:
		switch (c) {
		case EQUALS:
			tmp = *val;
			push(st);
			stack_set_ssp_val(st, tmp);
			stack_set_state(st, STATE_MAP_VAL);
			push(st);
			stack_set_state(st, STATE_VAR);
			stack_add_ctx(st, CTX_RIGHTBRACE|CTX_COMMA);
			break;

		case COMMA:
			if (*val)
				map_element(ret, val, NULL);
			push(st);
			stack_set_state(st, STATE_SCALAR);
			stack_add_ctx(st,
			    CTX_RIGHTBRACE|CTX_COMMA|CTX_EQUALS);
			break;
		case RIGHTBRACE:
			if (*val)
				map_element(ret, val, NULL);
			map_end(ret);
			stack_set_flags(st, STATE_DONE);
			break;
		}
		break;

	case STATE_MAP_VAL: 
		key = ret;
		pop(st);
		ret = stack_get_ssp_val(st);
		map_element(ret, key, val);

		if (c == COMMA) {
			push(st);
			/* Looking for another key/val */
			stack_set_state(st, STATE_SCALAR);
			stack_add_ctx(st,
			    CTX_RIGHTBRACE|CTX_COMMA|CTX_EQUALS);
		}
		if (c == RIGHTBRACE) {
			map_end(ret);
			stack_set_flags(st, STATE_DONE);
		}
		break;
	}
}

/* XXXrcd: L4M3 global but only for debugging */
char char_from_buf[2];
char *
char_from(int c)
{

	char_from_buf[0] = (char) c;
	char_from_buf[1] = 0;
	switch (c) {
	case BAD:		return "BAD";
	case EOL:		return "EOL";
	case EMPTY:		return "EMPTY";
	case SPACE:		return "SPACE";
	case COMMA:		return "COMMA";
	case BANG:		return "BANG";
	case AND:		return "AND";
	case EQUALS:		return "EQUALS";
	case LEFTBRACKET:	return "LEFTBRACKET";
	case RIGHTBRACKET:	return "RIGHTBRACKET";
	case LEFTBRACE:		return "LEFTBRACE";
	case RIGHTBRACE:	return "RIGHTBRACE";
	case CRLF:		return "CRLF";
	default:		return char_from_buf;
	}
}

struct self *
parse_init()
{
	struct self	*self;

	self = malloc(sizeof(*self));

	if (self) {
		memset(self, 0x0, sizeof(*self));
		self->p.remnant = BAD;
		self->p.lexstate = LEX_NORMAL;
	}
	return self;
}

void
parse_reset(struct self *self)
{
	struct stack	**st = &self->st;
	ssp_val		 *ret;

	/* XXXrcd: free internals to stop leaking... */

	while (!ST_IS_EMPTY(st)) {
		ret = stack_get_ssp_val(st);

		if (ret && *ret) {
			switch (stack_get_state(st)) {
			case STATE_SCALAR:	string_free(ret);	break;
			case STATE_MAP:		map_free(ret);		break;
			case STATE_LIST:
			case STATE_SPLIST:	list_free(ret);		break;
			}
		}

		pop(st);
	}

	memset(self, 0x0, sizeof(*self));
	self->p.remnant = BAD;
	self->p.lexstate = LEX_NORMAL;
}

void
parse_free(struct self *self)
{

	/* XXXrcd: really chase this up properly, d00d. */
	free(self);
}

int
parse_append(struct self *self, char *input, int len)
{
	struct parse	  pars;
	struct parse	 *p;
	struct stack	**st;

	/* XXXrcd: LAME, rewrite */

	self->p.input = input;
	self->p.inlen = strlen(self->p.input);
	self->p.pos   = self->p.input;

	st = &self->st;
	p  = &self->p;

	if (ST_IS_EMPTY(st)) {
		D(fprintf(stderr, "Stack is empty, let's go...\n"));
		push(st);
		stack_set_state(st, STATE_SPLIST);
		self->results = stack_get_ssp_val(st);
		list_begin(self->results);
		push(st);
		stack_set_state(st, STATE_VAR);
		stack_add_ctx(st, CTX_SPACE|CTX_CRLF);
		push(st);
		stack_set_state(st, STATE_SMTPLIKE);
	}

	parse(self);

	if (self->done && stack_get_ssp_val(st) == self->results)
		return 0;
	return 1;
}

int
unmarshall(struct self *self, char *input, int len)
{
	struct parse	  pars;
	struct parse	 *p;
	struct stack	**st;
	ssp_val		 *ret;
	ssp_val		 *key;
	ssp_val		 *val;
	ssp_val		  tmp;
	int		  state;
	int		  c;

	/* XXXrcd: LAME, rewrite */

D(fprintf(stderr, "unmarshalling: '%s'\n", input));

	parse_reset(self);

	self->p.input = input;
	self->p.inlen = strlen(self->p.input);
	self->p.pos   = self->p.input;

	st = &self->st;
	p  = &self->p;

	if (ST_IS_EMPTY(st)) {
		D(fprintf(stderr, "Stack is empty, let's go...\n"));
		push(st);
		stack_set_state(st, STATE_SPLIST);
		self->results = stack_get_ssp_val(st);
		list_begin(self->results);
		push(st);
		stack_set_state(st, STATE_VAR);
		stack_add_ctx(st, CTX_SPACE|CTX_CRLF);
	}

	self->done = 1;
	parse(self);

	return self->done;
}

int
parse(struct self *self)
{
	struct parse	  pars;
	struct parse	 *p;
	struct stack	**st;
	ssp_val		 *ret;
	ssp_val		 *key;
	ssp_val		 *val;
	ssp_val		  tmp;
	int		  state;
	int		  c;

	D(fprintf(stderr, "enter parse, self  = %p\n", self));
	D(fprintf(stderr, "   self->p.input   = %s\n", self->p.input));
	D(fprintf(stderr, "   self->done      = %d\n", self->done));
	D(fprintf(stderr, "   self->code      = %d\n", self->code));
	D(fprintf(stderr, "   self->st        = %p\n", self->st));
	D(fprintf(stderr, "   self->results   = %p\n", self->results));
	D(fprintf(stderr, "   *self->results  = %p\n", 
	    self->results?*self->results:0));

	st = &self->st;
	p  = &self->p;

	for (;;) {
		c = get_next_lex(p);

		state = stack_get_state(st);
D(fprintf(stderr, "loop got '%s' in state = %x\n", char_from(c), state));
		switch (c) {
		case EOL:
D(fprintf(stderr, "EOL: state = %x\n", state));
			/* We should just continue later... */
			return 0;

		case CRLF:
// if (state == STATE_SCALAR) break; /* XXXrcd: lame lame lame */
			/* XXXrcd: hmmm, if we're already in STATE_SMTPLIKE? */
			/* How about EOL? */
			if (self->done == 1) {
				D(fprintf(stderr, "we're done: state=0x%x\n",
				    state));
				if (state == STATE_SCALAR)
					stack_set_flags(st, STATE_DONE);

				if (state == STATE_VAR)
					pop(st);

				state = stack_get_state(st);
				if (stack_get_flags(st) & STATE_DONE)
					state_done(p, st, EOL);

				state = stack_get_state(st);
				ret = stack_get_ssp_val(st);
				list_end(ret);
				return 0;
			} else {
				push(st);
				stack_set_state(st, STATE_SMTPLIKE);
				continue;
			}
			break;

		case BAD:
			return c;
		}

		if (stack_get_flags(st) & STATE_DONE) {
			state_done(p, st, c);
			continue;
		}

		switch (state) {
		case STATE_VAR:		state_var(p, st, c);		break;
		case STATE_SCALAR:	state_scalar(p, st, c);		break;
		case STATE_SMTPLIKE:	state_smtplike(self, c);	break;
		case STATE_DONE:	state_done(p, st, c);		break;
		default:
			/* XXXrcd: hmmm, better errors here... */
			return BAD;
		}
	}
}

#if 0
#ifdef USE_PERL5
void *
tokenise(char *input, int size)
{
	struct stack	*st = NULL;
	struct parse	 pars;
	ssp_val		 res;

	parse(&st, &res, input, size);

	return res;
}
#else
int
main(int argc, char **argv)
{
	struct stack	*st = NULL;
	struct parse	 pars;
	ssp_val		 res;

	pars.remnant = BAD;
	while (*++argv) {
		pars.input = *argv;
		pars.inlen = strlen(*argv);
		pars.pos = pars.input;

		parse(&pars, &st, &res);
		fprintf(stderr, "We got: res = %p\n", res);
	}

	return 0;
}
#endif
#endif
