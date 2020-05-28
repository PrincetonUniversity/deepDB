#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include "threads.h"
#include <stdatomic.h>

#define NULL 0

#define N 200

extern void *malloc(size_t n);
extern void free(void *p);

typedef struct tree{
  int key;
  _Atomic void **value;
  _Atomic struct tree **left, **right;
} tree;
typedef _Atomic struct tree **treebox;
typedef _Atomic void **valuepointer;
treebox tb;

lock_t thread_lock[N];

void *surely_malloc(size_t n)
{
  void *p = malloc(n);
  if (!p)
    exit(1);
  return p;
}

treebox treebox_new(void)
{
  treebox p = (treebox)surely_malloc(sizeof(*p));
  atomic_store(p, NULL);
  return p;
}

void treebox_free(treebox b)
{
  struct tree *t = *b;
  if (t != NULL)
  {
    treebox_free(t->right);
    treebox_free(t->left);
    free(t->value);
    free(t);
  }
  free(b);
}

void insert(treebox tb, int x, void *value)
{
  struct tree *t;
  for (;;)
  {
    t = atomic_load(tb);
    if (t == NULL)
    {
      struct tree *p = (struct tree *)surely_malloc(sizeof *p);
      p->key = x;
      valuepointer v = (valuepointer)surely_malloc(sizeof *v);
      atomic_store(v, value);
      p->value = v;
      treebox lp = (treebox)surely_malloc(sizeof(*p));
      *lp = NULL;
      p->left = lp;
      treebox rp = (treebox)surely_malloc(sizeof(*p));
      *rp = NULL;
      p->right = rp;
      int result = atomic_compare_exchange_strong(tb, &t, p);
      if (result)
      {
        return;
      }
      else
      {
        free(v);
        free(lp);
        free(rp);
        free(p);
        continue;
      }
      return;
    }
    else
    {
      int y = t->key;
      if (x < y)
      {
        tb = t->left;
      }
      else if (y < x)
      {
        tb = t->right;
      }
      else
      {
        atomic_store(t->value, value);
        return;
      }
    }
  }
}

void *lookup(treebox tb, int x)
{
  struct tree *t = atomic_load(tb);
  void *v;
  while (t != NULL)
  {
    int y = t->key;
    if (x < y)
    {
      t = atomic_load(t->left);
    }
    else if (y < x)
    {
      t = atomic_load(t->right);
    }
    else
    {
      v = atomic_load(t->value);
      return v;
    }
  }
  return "value not found";
}

void *thread_func_insert(void *args)
{
  lock_t *l = (lock_t *)args;
  for (int i = 1; i <= 100; i++)
  {
    insert(tb, i, "value");
  }
  printf("insert thread done\n");
  release2((void *)l);
  printf("insert thread release thread lock\n");
  return (void *)NULL;
}
void *thread_func_lookup(void *args)
{
  lock_t *l = (lock_t *)args;
  for (int i = 1; i <= 100; i++)
  {
    printf("%s\n", lookup(tb, i));
  }
  printf("lookup thread done\n");
  release2((void *)l);
  printf("lookup thread release thread lock\n");
  return (void *)NULL;
}

int main(void)
{
  tb = treebox_new();

  /* Spwan 100 lookup thread */
  for (int i = 0; i < 100; i++)
  {
    lock_t *l = &(thread_lock[i]);
    makelock((void *)l);
    spawn((void *)&thread_func_lookup, (void *)l);
  }

  /* Spwan 100 insert thread */
  for (int i = 100; i < 200; i++)
  {
    lock_t *l = &(thread_lock[i]);
    makelock((void *)l);
    spawn((void *)&thread_func_insert, (void *)l);
  }
  printf("I am done to spwan all thread here \n");
  /*JOIN */
  for (int i = 0; i < N; i++)
  {
    lock_t *l = &(thread_lock[i]);
    acquire((void *)l);
    freelock2((void *)l);
  }
  treebox_free(tb);
  printf("Everything done here \n");
  return 0;
}
