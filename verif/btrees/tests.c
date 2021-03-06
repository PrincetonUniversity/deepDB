
/* Testing the C btree implementation for insertion */

#include <stdio.h>
#include <stdlib.h>
#include "relation.h"

static void test_insert(void) {
  enum {TEST_RANGE = 3000};
  enum {NUM_INSERTS = 10000};

  int i;
  Key key;
  unsigned long record;
  Relation_T relation = RL_NewRelation();
  Cursor_T cursor = RL_NewCursor(relation);
  
  
  for (i=0; i<NUM_INSERTS; i++) {

    key = rand() % TEST_RANGE;
    record = key;

    /* testing insertion */
    RL_PutRecord(cursor, key, record);

    key = rand() % TEST_RANGE;

    RL_MoveToKey(cursor,key);

    if (RL_CursorIsValid(cursor) == True) {
      /* testing GetRecord */
      RL_GetRecord(cursor);
    }
    

  }
  
  RL_PrintTree(relation);
  RL_PrintCursor(cursor);

  return;
}

int main () {
  test_insert();
  return 0;

}
  
