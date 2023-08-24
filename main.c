#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void get_options()
{
    char argv_str[] = "-o file.txt -f input.txt -n 10 -+ -adadaap";

    char *input_file = NULL;
    char *output_file = "a.out";
    int group_size = 0;
    int group_size_provided = 0;
    int include_a = 0, include_t = 0, include_c = 0, include_g = 0, include_plus = 0;

    char *token = strtok(argv_str, " ");
    while (token != NULL)
    {
        if (token[0] == '-')
        {
            // Iterate through the characters after '-'
            for (int i = 1; i < strlen(token); i++)
            {
                switch (token[i])
                {
                case 'f':
                    input_file = strtok(NULL, " ");
                    break;
                case 'o':
                    output_file = strtok(NULL, " ");
                    break;
                case 'n':
                    group_size = atoi(strtok(NULL, " "));
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
            }
        }
        token = strtok(NULL, " ");
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
    get_options();
    return 0;
}
