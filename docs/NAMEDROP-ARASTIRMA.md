# NameDrop efekti: araştırma ve plan

Tarih: 2026-10-23. Amaç: iPhone'daki NameDrop efektini, Mac'te bir monitörden diğerine geçerken birebir oynatmak.

## 1. Apple'ın efekti gerçekte ne yapıyor

Kaynak: Apple'ın tanıtım videosu (MartinRGB'nin blogundaki `ios_namedrop.mp4`), kare kare incelendi.

| Zaman | Ne oluyor |
|---|---|
| Yaklaşma | Telefonlar yaklaştıkça ekranın temas kenarına yakın bölgesi giderek **bulanıklaşıyor** ve **beyazlaşıyor**. |
| Toplanma | Temas kenarında (kamera / Dynamic Island) güçlü bir **beyaz ışık** birikiyor. |
| Patlama (~0,1 sn) | Temas noktasından **büyük, yumuşak kenarlı parlak beyaz bir disk** dışa doğru büyüyor. Kenarında hafif **mavi / gökkuşağı** tonu var, içi çok bulanık. |
| Dalga | Disk büyürken arkasındaki içerik bir **şok dalgasıyla** bükülüyor; dalganın geçtiği yer aydınlanıyor. |
| Parçacıklar | Dalgayla birlikte merkezden dışarı fırlayan ince **parçacık çizgileri** çıkıyor. |
| Esneme | Bütün ekran Y ekseninde kısa bir an **esniyor**. |
| Bitiş | Bulanıklık çözülüyor ve yeni içerik (iPhone'da kartvizit) netleşiyor. |

Asıl sonuç: efektin kalbinde ince bir su halkası değil, **bulanıklık + büyüyen beyaz ışık diski** var. Önceki denemelerimiz yalnızca halka olduğu için benzemedi.

## 2. Bulunan yeniden yapımlar

| Kaynak | Ne işe yarıyor | Lisans |
|---|---|---|
| [MartinRGB/iOS17_Namedrop_R3F](https://github.com/MartinRGB/iOS17_Namedrop_R3F) ([canlı](https://martinrgb.github.io/iOS17_Namedrop_R3F/), [anlatım](https://martinrgb.github.io/blog/#/Namedrop_Animation)) | En kapsamlısı. Katmanlar: dönüşüm → Dual Kawase bulanıklık → şok dalgası → parçacık → ışık. Zamanlamayı kare kare anlatıyor. | Yok (kod kopyalanamaz, teknik alınır) |
| [dkun7944 AirDrop gist'i](https://gist.github.com/dkun7944/2f793643e469029fb4e7d700f0645ffc) | Tek bir SwiftUI `layerEffect`. Toplanma evresi (esneme, artan bulanıklık, yukarı çıkan ışık, üstte beyaz ışık) ve patlama evresi (art arda iki şok halkası, beyaz parlama). | Yok |
| [cyrilzakka/NameDrop](https://github.com/cyrilzakka/NameDrop) | Yalnızca şok dalgası. İkinci denememiz buydu. | MIT |
| [WWDC24: Create custom visual effects with SwiftUI](https://developer.apple.com/videos/play/wwdc2024/10151/) | Apple'ın resmî ripple shader'ı. İlk denememiz buydu. | Apple örnek kodu |
| [uvolchyk: Sparkling shiny things](https://uvolchyk.me/blog/sparkling-shiny-things-with-metal-and-swiftui) | Metal ile parçacık tekniği. | Blog |

MartinRGB'nin anlatımından, Apple'ın sıralaması:
1. Alttan bir ışık yukarı kayıyor, üstteki ışıkla buluşuyor; üstteki ışık güçleniyor.
2. Işık yolun yarısına gelince bulanıklık başlıyor.
3. İki ışık buluşunca dalga ve parçacık patlaması tetikleniyor.
4. Parçacıklar biterken yeni içerik giriyor.

MartinRGB'ye göre Apple ışık için büyük ihtimalle basit bir "bulanık daire" görseli kullanıyor. Dalga bölgesi ayrıca parlatılıyor.

## 3. Mac'e uyarlama

iPhone'daki "iki telefonun yaklaşması", Mac'te "imlecin iki monitörün ortak kenarına yaklaşması" oluyor:

| iPhone | Mac (ScreenDrop) |
|---|---|
| Telefonlar yaklaşıyor | İmleç ortak kenara yaklaşıyor (son ~150 pt). Toplanma evresi bu mesafeye bağlı oynar. |
| Temas | İmleç kenarı geçiyor. |
| Patlama | İki ekranda da, geçiş noktasında ışık diski, dalga ve parçacıklar. |
| Kartvizit girişi | Yok; bulanıklık çözülür, masaüstü geri gelir. |

## 4. Teknik seçenekler

**A. İzinsiz:** Bulanıklık için macOS'un pencere arkası blur'u (material) kullanılır. Ekran görüntüsü alınmaz, izin gerekmez. Işık diski, gökkuşağı kenar, parçacıklar ve parlama birebir yapılır. Pencere içeriği bükülemez (dalga ve esneme olmaz).

**B. Ekran Kaydı izinli (tam):** Geçiş anında ekranın o bölgesinin görüntüsü alınır (ScreenCaptureKit), tek bir Metal shader her şeyi yapar: bulanıklık, esneme, şok dalgası, ışık diski, parlama, parçacıklar. Apple'a en yakın sonuç bu.

İki seçenekte de Swift + SwiftUI + Metal kullanılır. Python sürümü Beamer efektleri için yazılmıştı, bu iş için uygun değil.

## 5. Faz planı (B seçeneği için)

1. **F1, kare doğrulama:** Shader'ı uygulamadan önce ekran dışında kare kare çizip Apple'ın video kareleriyle yan yana karşılaştırmak. Görüntü onaylanmadan uygulamaya geçilmez.
2. **F2, uygulama:** Menü çubuğu, geçiş algılama, kenara yaklaşma ölçümü, ScreenCaptureKit ile görüntü, iki ekranda overlay.
3. **F3, ince ayar:** Gerçek monitörlerde zamanlama ve renk ayarı.
