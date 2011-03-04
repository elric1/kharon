/* $Id$ */

#ifndef KHARON_ARRAYHASH_INCLUDE
#define KHARON_ARRAYHASH_INCLUDE

// #define DEBUG 1
#if DEBUG
#define D(x)	do { if (DEBUG) x; } while (0)
#else
#define D(x)
#endif

typedef void *ssp_val;

#define STATE_BITMASK		0xff000000
#define STATE_REMAINS		0x0000000f

#define STATE_SMTPLIKE		0x01000000
#define STATE_TOKENISE		0x02000000
#define STATE_VAR		0x03000000
#define STATE_SCALAR		0x04000000
#define STATE_LIST		0x05000000
#define STATE_MAP_KEY		0x06000000
#define STATE_MAP_VAL		0x07000000
#define STATE_SPLIST		0x08000000
#define STATE_CHAR		0x09000000
#define STATE_MAP		0x0a000000
#define STATE_UNDEF		0x0b000000

#define STATE_FLAGMASK		0x00f00000
#define STATE_DONE		0x00100000
#define STATE_FIRST		0x00200000

#define STATE_CTXMASK		0x000ffff0
#define CTX_LEFTBRACE		0x00000010
#define CTX_RIGHTBRACE		0x00000020
#define CTX_LEFTBRACKET		0x00000040
#define CTX_RIGHTBRACKET	0x00000080
#define CTX_COMMA		0x00000100
#define CTX_EQUALS		0x00000200
#define CTX_BANG		0x00000400
#define CTX_AND			0x00000800
#define CTX_SPACE		0x00001000
#define CTX_CRLF		0x00002000
#define CTX_BACKSLASH		0x00004000

struct entry {
	union {
		ssp_val	ret;
		int	code;
	} u;
	int		state;
};


#define ST_SIZE		256
#define ST_ENTRY(st)	((*(st))->e[(*(st))->cur])
#define ST_DECLARE(OUTER, INNER)	\
	OUTER {				\
		INNER	 e[ST_SIZE];	\
		OUTER	*next;		\
		int	 cur;		\
	}

#define ST_IS_EMPTY(st)	((!(*st)) || (!((*(st))->next) && ((*(st))->cur < 0)))

#define ST_PUSH(st)	do {					\
		void	*old;					\
								\
		old = *(st);					\
		if (!*(st) || (*(st))->cur >= ST_SIZE) {	\
			(*(st)) = malloc(sizeof(**(st)));	\
			(*(st))->next = old;			\
			(*(st))->cur = 0;			\
		} else {					\
			(*(st))->cur++;				\
		}						\
	} while (0)

#define ST_POP(st)	do {					\
		void	*tmp;					\
								\
		(*(st))->cur--;					\
		if ((*(st))->cur < 0) {				\
			tmp   = *(st);				\
			*(st) = (*(st))->next;			\
			free(tmp);				\
		}						\
	} while (0)
 

ST_DECLARE(struct stack, struct entry);

struct parse {
	char		*input;
	int		 inlen;
	char		*pos;
	int		 remnant;
	int		 lexstate;
#define LEX_NORMAL		0x0000
#define LEX_GOTBACKSLASH	0x1000
#define LEX_GOTHEXDIGIT		0x2000
#define LEX_GOTCR		0x3000
};

struct self {
	struct parse	 p;
	struct stack	*st;
	ssp_val		*results;
	void		*banner;
	int		 code;
	int		 done;
};


#define	BAD		256
#define EOL		257
#define EMPTY		258
#define SPACE		(-' ')
#define COMMA		(-',')
#define BANG		(-'!')
#define AND		(-'&')
#define EQUALS		(-'=')
#define LEFTBRACKET	(-'[')
#define RIGHTBRACKET	(-']')
#define LEFTBRACE	(-'{')
#define RIGHTBRACE	(-'}')
#define CRLF		(-'\n')

struct self	*parse_init(void);
void		 parse_free(struct self *self);

void		*tokenise(char *, int);
#if 0
static int	 get_next_lex(struct parse **);
static int	 get_next_scalar(struct parse **, ssp_val *, int);
static int	 get_next_list(struct parse **, ssp_val *);
static int	 get_next_map(struct parse **, ssp_val *);
static int	 get_next_var(struct parse **, ssp_val *, int);
// static SV	*mkSV_ssp_val(struct ssp_val *);
#endif

/*
 * The Perl parse callbacks...
 */

#if 0
static void	list_begin(ssp_val *);
static void	list_element(ssp_val *, ssp_val *);
static void	list_end(ssp_val *);
static void	map_begin(ssp_val *);
static void	map_element(ssp_val *, ssp_val *, ssp_val *);
static void	map_end(ssp_val *);
#endif


struct encode_state	*encode_init(void *, int);
struct encode_state	*marshall_init(void *);
int			 encode(struct encode_state **, char *, int);
#endif
