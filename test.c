#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <openssl/md5.h>
#include "openssl/evp.h"

// Assuming XSIZE is defined
#define XSIZE 10
typedef uint8_t cell_state_t;
typedef cell_state_t line_t[XSIZE];

char* ca_buffer_to_hex_str(const uint8_t* buf, size_t buf_size)
{
  char *retval, *ptr;

  retval = ptr = calloc(MD5_DIGEST_LENGTH * 2 + 1, sizeof(*retval));
  for (size_t i = 0; i < MD5_DIGEST_LENGTH; i++) {
    snprintf(ptr, 3, "%02X", buf[i]);
    ptr += 2;
  }

  return retval;
}


void print_byte_array(const uint8_t* array, size_t size) {
    for (size_t i = 0; i < size; i++) {
        printf("0x%02X", array[i]);

        // Add a comma and space after each byte, except for the last one
        if (i < size - 1) {
            printf(", ");
        }
    }
    printf("\n");
}


void ca_hash_and_print(line_t *buf, int lines)
{
    uint8_t hash[MD5_DIGEST_LENGTH];
    uint32_t md_len;
    EVP_MD_CTX *ctx = EVP_MD_CTX_new();
    EVP_DigestInit_ex(ctx, EVP_md5(), NULL);

    EVP_DigestUpdate(ctx, buf, lines * sizeof(*buf));
    EVP_DigestFinal_ex(ctx, hash, &md_len);

    //size_t size = sizeof(hash) / sizeof(hash[0]);
    //print_byte_array(hash,size);

    char* hash_str = ca_buffer_to_hex_str(hash, MD5_DIGEST_LENGTH);
    printf("hash: %s\n", (hash_str ? hash_str : "ERROR"));
    free(hash_str);

    EVP_MD_CTX_free(ctx);
}

int main() {
    // Initialize your line here with integers
    line_t *from;
    from = malloc((2) * sizeof(*from));
    for (int y = 0;  y < 2;  y++) {
        for (int x = 0;  x < XSIZE;  x++) {
            if (y == 1){
              from[y][x] = 1;
            }
            else if(x % 2 == 0){
                from[y][x] = 0;
            }
            else{
                from[y][x] = 1;
            }
        }
    }
    // Initialize the line with some values (for example, 0 or 1)

    ca_hash_and_print(from,2);
    free(from);
    return 0;
}