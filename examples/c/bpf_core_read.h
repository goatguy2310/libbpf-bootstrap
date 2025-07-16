#ifndef __BPF_CORE_READ_H__
#define __BPF_CORE_READ_H__

#define ___concat(a, b) a ## b
#define ___apply(fn, n) ___concat(fn, n)
#define ___nth(_1, _2, _3, _4, _5, _6, _7, _8, _9, _10, __11, N, ...) N

#define ___narg(...) ___nth(_, ##__VA_ARGS__, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0)

#define ___arrow1(a) a
#define ___arrow2(a, b) a->b
#define ___arrow3(a, b, c) a->b->c
#define ___arrow4(a, b, c, d) a->b->c->d
#define ___arrow5(a, b, c, d, e) a->b->c->d->e
#define ___arrow6(a, b, c, d, e, f) a->b->c->d->e->f
#define ___arrow7(a, b, c, d, e, f, g) a->b->c->d->e->f->g
#define ___arrow8(a, b, c, d, e, f, g, h) a->b->c->d->e->f->g->h
#define ___arrow9(a, b, c, d, e, f, g, h, i) a->b->c->d->e->f->g->h->i
#define ___arrow10(a, b, c, d, e, f, g, h, i, j) a->b->c->d->e->f->g->h->i->j
#define BPF_CORE_READ(...) ___apply(___arrow, ___narg(__VA_ARGS__))(__VA_ARGS__)

#endif
