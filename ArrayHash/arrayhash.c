/* $Id: utils.pm,v 1.22 2009/10/27 15:23:32 dowdes Exp $ */

#include <sys/types.h>
#include <sys/stat.h>

#include <fcntl.h>
#include <malloc.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "arrayhash.h"

#define STR_BUF_LEN	1

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
	union enc_entry_union {
		void		*data;
		char		 c;
	} u;
	struct encode_state	*prev;
};

ST_DECLARE(struct encode_state, struct enc_entry);

struct encode_state *marshall_init(void *);
struct encode_state *encode_init(void *, int);
int encode(struct encode_state **, char *, int);
void encode_free(struct encode_state **);
int parse_append(struct self *, char *, int);
void parse_reset(struct self *);
int unmarshall(struct self *, char *, int);

void encode_push(struct encode_state **, int, void *);
void encode_push_c(struct encode_state **, int, char);
void encode_pop(struct encode_state **);
void encode_undef(struct encode_state **, char *, int *, int);
void encode_list(struct encode_state **, char *, int *, int);
void encode_map(struct encode_state **, char *, int *, int);
void encode_char(struct encode_state **, char *, int *, int);
void encode_var(struct encode_state **, char *, int *, int);
void encode_scalar(struct encode_state **, char *, int *, int);

int parse(struct self *);
void state_done(struct parse *, struct stack **, int);
const char * char_from(int);

void
encode_push(struct encode_state **st, int state, void *data)
{

	D(fprintf(stderr, "encode_push, enter\n"));
	ST_PUSH(st);
	ST_ENTRY(st).state  = state;
	ST_ENTRY(st).first  = 1;
	ST_ENTRY(st).pos    = 0;
	ST_ENTRY(st).u.data = data;
}

void
encode_push_c(struct encode_state **st, int state, char c)
{

	D(fprintf(stderr, "encode_push, enter\n"));
	ST_PUSH(st);
	ST_ENTRY(st).state  = state;
	ST_ENTRY(st).first  = 1;
	ST_ENTRY(st).pos    = 0;
	ST_ENTRY(st).u.c    = c;
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
		ST_ENTRY(st).u.data = encode_list_iter(ST_ENTRY(st).u.data);

		if (!ST_ENTRY(st).u.data) {
			/* XXXrcd: failure! */
		}
	}

	tmp = encode_list_next(ST_ENTRY(st).u.data);

	if (!tmp) {
		encode_list_free(ST_ENTRY(st).u.data);
		if ((ST_ENTRY(st).state & STATE_BITMASK) != STATE_SPLIST) {
			ST_ENTRY(st).state  = STATE_CHAR;
			ST_ENTRY(st).u.data = (void *) ']';
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
		ST_ENTRY(st).u.data = encode_map_iter(ST_ENTRY(st).u.data);
	}

	if (!encode_map_next(ST_ENTRY(st).u.data, &key, &val)) {
		ST_ENTRY(st).state = STATE_CHAR;
		ST_ENTRY(st).u.c   = '}';
		return;
	}

	encode_push(st, STATE_VAR|CTX_COMMA|CTX_RIGHTBRACE|CTX_EQUALS, val);
	encode_push(st, STATE_CHAR, (void *) '=');
	encode_push(st, STATE_SCALAR|CTX_COMMA|CTX_RIGHTBRACE|CTX_EQUALS, key);
	if (!first)
		encode_push_c(st, STATE_CHAR, ',');

}

void
encode_char(struct encode_state **st, char *ret, int *pos, int len)
{

	D(fprintf(stderr, "encode_char, enter\n"));
	ret[(*pos)++] = (char) ST_ENTRY(st).u.c;
	encode_pop(st);
}

void
encode_var(struct encode_state **st, char *ret, int *pos, int len)
{

	D(fprintf(stderr, "encode_var, enter\n"));
	ST_ENTRY(st).state &= ~STATE_BITMASK;
	ST_ENTRY(st).state |= encode_get_type(ST_ENTRY(st).u.data);
}

void
encode_scalar(struct encode_state **st, char *ret, int *pos, int len)
{
	unsigned char	*str;
	int		 ctx;
	int		 str_len;
	int		 i;
	int		 intercharpos;

	D(fprintf(stderr, "encode_scalar, enter\n"));
	str = (unsigned char *)encode_get_scalar(ST_ENTRY(st).u.data, &str_len);

	if (str_len == 0) {
		ret[(*pos)++] = '\\';
		ST_ENTRY(st).state = STATE_CHAR;
		ST_ENTRY(st).u.c   = 'z';
		return;
	}

	ctx = ST_ENTRY(st).state & STATE_CTXMASK;
	ctx |= CTX_BACKSLASH;

	for (i=ST_ENTRY(st).pos; i < str_len && (*pos) < len; ) {
		int	tmpctx = ctx;
		int	ctxptr = 0;
		int	quote  = 0;
		char	tmpchar;

		D(fprintf(stderr, "encode_scalar, enter: pos=%d len=%d\n",
		    i, str_len));

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
			default:
				/* Should not happen, set tmpchar to make
				 * the compiler happy...
				 */
				tmpchar = '\\';
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
	if (i >= str_len)
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

static inline int
stack_get_code(struct stack **st)
{

	return ST_ENTRY(st).u.code;
}

static inline void
stack_set_code(struct stack **st, int code)
{

	ST_ENTRY(st).u.code = code;
}

static inline ssp_val *
stack_get_ssp_val(struct stack **st)
{

	return &(ST_ENTRY(st).u.ret);
}

static inline void
stack_set_ssp_val(struct stack **st, ssp_val ret)
{

	ST_ENTRY(st).u.ret = ret;
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

	D(fprintf(stderr, "pushing...\n"));
	ST_PUSH(st);
	ST_ENTRY(st).state = 0;
	stack_set_ssp_val(st, NULL);
}

/* XXXrcd: pop needs be rewritten */
static inline void
pop(struct stack **st)
{

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

static inline void
state_smtplike(struct self *self, int c)
{
	struct stack	**st = &self->st;
	int		  code;

	code = stack_get_code(st);

	D(fprintf(stderr, "state_smtplike code=%d got '%c'\n", code, c));

	if (code < 1000 && c >= '0' && c <= '9') {
		if (code > 999) {
			self->done = BAD;
			return;
		}

		code *= 10;
		code += c - '0';

		stack_set_code(st, code);
		return;
	}

	switch (c) {
	case SPACE:
		if (code < 100) {
			self->done = BAD;
			return;
		}

		break;

	case '.':
		if (code < 1000)
			self->done = 1;

	case '-':
		if (code < 100) {
			self->done = BAD;
			return;
		}

		if (code < 1000) {
			code += 1000;
			stack_set_code(st, code);
			break;
		}
		/*FALLTHROUGH*/

	default:
		if (code < 1100) {
			self->done = BAD;
			return;
		}
		self->p.remnant = c;
		self->code = code - 1000;
		/* XXXrcd: should we check if lines have matching codes? */
		pop(st);
		break;
	}
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

	if (chr_matches_ctx(st, c)) {
		stack_set_flags(st, STATE_DONE);
		p->remnant = c;
		return;
	}

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

	for (i=0; i < (int) sizeof(buf); i++) {
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
const char *
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
	void		 *banner;

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

	banner = self->banner;
	memset(self, 0x0, sizeof(*self));
	self->banner = banner;
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
	struct parse	 *p;
	struct stack	**st;

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
	struct parse	 *p;
	struct stack	**st;
	ssp_val		 *ret;
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

		if (self->done == BAD)
			return BAD;

		state = stack_get_state(st);
		D(fprintf(stderr, "loop got '%s' in state = %x\n",
		    char_from(c), state));

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
		default:
			/* XXXrcd: hmmm, better errors here... */
			return BAD;
		}
	}
}
