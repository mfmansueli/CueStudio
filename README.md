# CueStudio

## SwiftLint e Xcode Cloud

O target `Cue Studio` executa o SwiftLint uma vez por build, no Run Script `SwiftLint`.
Não há plugin de lint. A configuração `.swiftlint.yml` cobre o app, os testes unitários
e os testes de UI; suas regras também se aplicam ao build remoto.

O Xcode Cloud fornece Homebrew, mas não instala automaticamente o SwiftLint.
`ci_scripts/ci_post_clone.sh`, ao lado de `Cue Studio.xcodeproj`, instala a ferramenta
com `brew install swiftlint` quando ela ainda não está disponível. O script deve permanecer
executável no Git (`100755`). Tanto o post-clone quanto o Run Script incluem
`/opt/homebrew/bin` e `/usr/local/bin` no PATH e registram o caminho e a versão do SwiftLint.
O PATH do post-clone não é herdado pela etapa de build. Falhas de instalação ou lint
interrompem a execução.

A configuração foi validada localmente com SwiftLint **0.65.1**. O Homebrew instala sua
versão estável disponível, sem fixar uma versão neste projeto. Compare as versões nos
logs locais e remotos ao atualizar a ferramenta; valide eventuais novas violações sem
afrouxar as regras. Para instalar e conferir localmente:

```sh
brew install swiftlint
swiftlint version
swiftlint lint --quiet
```

Para testar novamente no Xcode Cloud:

1. Faça commit e push das alterações, incluindo o modo executável do post-clone.
2. Inicie um novo build do workflow para esse commit e o scheme compartilhado `Cue Studio`.
3. Confira a execução de `ci_post_clone.sh` e seus logs de instalação, caminho e versão.
4. Confira os logs do Build Phase `SwiftLint`: a ferramenta deve ser encontrada e o lint
   deve concluir sem violações, antes de continuar o build.

A instalação real no ambiente Cloud e o resultado do build remoto precisam ser
confirmados nessa nova execução; a validação local não substitui esse teste.
