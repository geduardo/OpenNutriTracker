ah, se me olvidó actualizar sobre esto

la app ya la tengo, funciona perfectamente y está hecha a mi gusto, el proceso me ha hecho re-pensar hacia donde nos dirigimos en el mundo del software, pero más sobre eso al final

resumen:

No he programado en Android en mi p vida, pero algo de programación sé, y bastante de como controlar agentes de LLM

Me he hecho una app con las features que a mí me interesa:

- IA (Gemini u OpenAI, your choice) para descomponer los nutrientes a partir de una foto y/o texto
- Scanner de codigos de barras, si un item no está, la app te deja hacer una foto a la etiqueta y el LLM añade el item a una base de datos interna
- Agrupa entre comidas y set de ingredientes según yo le diga
- Se conecta con Google Health Connect para sacar mis medidas de la báscula Withings que uso

Y un montón de detallitos que no os importan pero que lo hago ha mi gusto (dashboards, etc...)

Una vez tenía el sistema de logging hecho, lo que quería es un método para ajustar el consumo de calorías parecido a lo que usa la app MacroFactor. Es una idea bastante buena, básicamente, si sabéis algo de teoría de control, lo que propone MacroFactor es tratar el la ingesta de calorías como un problema de control donde el setopoint deseado es tu tasa de cambio de peso (kg/semana). Básicamente la idea es planterlo como un closed control loop donde la input es el número de calorías y la output es el peso. La cosa es que tienes noisy observations (tu peso fluctúa mucho de un día para otro), y noisy inputs (ya que tú no controlas muy bien cuántas calorías metes). Luego hay un montón de complicaciones sobre qué pasa si varios días no te pesas, o no metes la comida por completo algún día etc... cosas para las que yo no tengo tiempo para pensar. Así que lo que hice es poner a Codex 5.4 xhigh a estudiarse los blogs de MacroFactor y hacer reverse engineering the su método, la verdad es que ha quedado bastante apañado, debería funcionar.

Luego lo han implementado Claude y GPT depende del qué (en general tiro de 5.4 para el backend y Opus 4.6 para front).

Cuánto tiempo me ha llevado? Pues unas cuantas horas la verdad:
1h de explorar la app original y hacer el plan de implementación
1h de conseguir que el Android Studio SDK y le flutter me funken (es cierto que una vez funciona va como la seda)
Y luego varias horas de QA y back and forth con los agentes, 2 o 3

Pero es difícil asignar tiempo a este tipo de operaciones porque la mayoría del tiempo puedo estar haciendo otras cosas mientras los agentes trabajan, como por ejemplo escribir este texto

Me sale rentable? Pues monetariamente no, ya que una la sub anual de MacroFactor es de unos 50 pavos anuales, y la verdad, a mi salario las horas que le he echado cuestan bastante más que eso. Pero bueno, mi mujer también la va a usar, así que ponle 100 euros anuales... A eso le tienes que restar el gasto de tokens/subscripcion de los modelos que he usado. El gasto de los LLMs que procesan la imagen es despreciable, con Gemini 3 Flash es casi gratis y funciona bien.

Pero la cosa es que, primero, he aprendido como se hacen apps de Android. Muy fácil, haré más. Y segundo, ahora mismo tengo un software amoldado a mí y lo mejor de todo, que se actualiza a mi gusto. Si veo algo que no me gusta o veo un bug, lo apunto, le digo a mi agente de confianza que lo arregle y voilá, hecho. Mola un huevo.

Y eso me hace pensar que este es el futuro del software, y las plataformas que no se adapten morirán. Habrá intentos de regulatory capture por parte de las grandes (Apple, Google y muchas otras empresas hacen mucho dinero a partir de la venta de software), pero es que es una mejor experiencia. Puedes hacerte el software a medida por un coste muy reducido.

El futuro del software es aplicaciones con una especie de "autodesarrollo", donde el usuario pide una feature o un cambio y la aplicación se adapta a las necesidades del usuario. No es apto para todos los softwares, por ejemplo, hay mucho software con alta complejidad o que depende de mucha infraestructura (servicios de mensajería, streaming, etc...). Pero para la mayoría del software,
es el camino, sin ninguna duda.


