Plugin loading in zinit, with no fpath mod:

``` zsh
zinit light-mode silent for \
    mv'${PWD}/completions/_luaver -> ${PWD}/_luaver' \
    atclone'zinit creinstall -q "${PWD}/"'           \
    atpull'%atclone' blockf                          \
    disco0/luaver
```

If _luaver was moved into base plugin dir, it would be easier however:

``` zsh
zinit light-mode silent for disco0/luaver
```

(For later testing)