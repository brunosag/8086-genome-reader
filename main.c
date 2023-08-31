#include <stdio.h>
#include <stdlib.h>
#include <string.h>

char my_argv[64] = "  -o file.txt -f input.txt -n a -a";
char *argv_cursor = my_argv;
char *token;

int my_atoi(char *str)
{
    int result = 0;

    while (*str != '\0')
    {
        if (*str < '0' || *str > '9')
        {
            return -1;
        }

        result *= 10;
        result += *str;
        result -= '0';
        str++;
    }

    return result;
}

void argv_tok()
{
    // handle beginning of the string containing delims
    while (1)
    {
        if (*argv_cursor == ' ')
        {
            argv_cursor++;
            continue;
        }
        if (*argv_cursor == '\0')
        {
            token = NULL;
            return;
        }
        break;
    }

    token = argv_cursor;
    while (1)
    {
        if (*argv_cursor == '\0')
        {
            /*end of the input string and
            next exec will return NULL*/
            return;
        }
        if (*argv_cursor == ' ')
        {
            *argv_cursor = '\0';
            argv_cursor++;
            return;
        }
        argv_cursor++;
    }
}

void get_options()
{
    char *input_file = NULL;
    char *output_file = "a.out";
    int group_size = 0;
    int group_size_provided = 0;
    int include_a = 0, include_t = 0, include_c = 0, include_g = 0, include_plus = 0;

    argv_tok();
    while (token != NULL)
    {
        if (*token == '-')
        {
            char *token_cursor = token + 1;
            while (*token_cursor != '\0')
            {
                switch (*token_cursor)
                {
                case 'f':
                    argv_tok();
                    input_file = token;
                    break;
                case 'o':
                    argv_tok();
                    output_file = token;
                    break;
                case 'n':
                    argv_tok();
                    group_size = my_atoi(token);
                    if (!(group_size >= 1))
                    {
                        printf("Erro: parâmetro -n inválido. Informe um número maior ou igual a 1.\n");
                        return;
                    }
                    group_size_provided = 1;
                    break;
                case 'a':
                    include_a = 1;
                    break;
                case 't':
                    include_t = 1;
                    break;
                case 'c':
                    include_c = 1;
                    break;
                case 'g':
                    include_g = 1;
                    break;
                case '+':
                    include_plus = 1;
                    break;
                default:
                    printf("Erro: opção %s é inválida.\n", token);
                    return;
                }
                token_cursor++;
            }
        }
        argv_tok();
    }

    if (input_file == NULL)
    {
        printf("Erro: opção -f não encontrada. Informe o arquivo de entrada.\n");
        return;
    }
    if (group_size_provided == 0)
    {
        printf("Erro: opção -n não encontrada. Informe o tamanho dos grupos de bases.\n");
        return;
    }
    if (!(include_a || include_t || include_c || include_g || include_plus))
    {
        printf("Erro: opção -<atcg+> não encontrada. Informe as bases a serem processadas.\n");
        return;
    }

    printf("input_file: %s\n", input_file);
    printf("output_file: %s\n", output_file);
    printf("group_size: %d\n", group_size);
    printf("include_a: %d\n", include_a);
    printf("include_t: %d\n", include_t);
    printf("include_c: %d\n", include_c);
    printf("include_g: %d\n", include_g);
    printf("include_plus: %d\n", include_plus);
}

int main()
{
    printf("-----------------------------------------------------------------\n");
    printf("String: %s\n", argv_cursor);
    printf("-----------------------------------------------------------------\n");

    get_options();

    return 0;
}
