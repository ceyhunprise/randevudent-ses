# RandevuDent Ses — Türkiye'de barındırılan Ayla (deneme sürümü)

Ayla'nın Retell yerine tamamen kendi sunucunda çalışan sürümü. Konuşma, yazıya çevirme, yapay zekâ ve ses üretimi aynı sunucuda yapılır; **hiçbir veri Türkiye dışına çıkmaz**.

Bu ilk sürüm telefonsuzdur: Ayla ile tarayıcıdaki bir test sayfasından konuşursun. Amaç Türkçe ses kalitesini ve gecikmeyi denemek. Test başarılı olursa sonraki adım Netgsm/Verimor SIP hattını bağlamak.

| Görev | Bileşen | Klasör |
|---|---|---|
| Ses trafiği | LiveKit | `livekit.yaml` |
| Konuşma → yazı | faster-whisper (large-v3-turbo) | `stt/` |
| Yapay zekâ (beyin) | vLLM + Qwen3 (Apache 2.0) | `docker-compose.yml` |
| Yazı → Türkçe ses | EMA-TTS (Apache 2.0) | `tts/` |
| Konuşmayı yöneten ajan | LiveKit Agents | `agent/` |
| Test sayfası + HTTPS | FastAPI + Caddy | `web/`, `Caddyfile` |

---

## Kurulum (adım adım)

### 1. Kodu GitHub'a yükle

Sunucu kodu GitHub'dan indirecek. Bunun için:

1. [github.com/new](https://github.com/new) adresine git.
2. Depo adına `randevudent-ses` yaz, **Public** seç, **Create repository**'ye tıkla.
3. Açılan sayfada **uploading an existing file** bağlantısına tıkla.
4. Bu klasördeki tüm dosya ve klasörleri sürükleyip bırak, **Commit changes**'e tıkla.

> İçinde gizli bilgi yok. Şifreler ve anahtarlar sunucuda kurulum sırasında üretilir.

### 2. GPU sunucuyu aç (DT Cloud örneği)

1. DT Cloud paneline giriş yap, **Virtual Machines** sayfasında **Create A Virtual Machine**'e tıkla.
2. İmaj olarak **GPU-Optimized** sekmesinden bir **Ubuntu 22.04** imajı seç.
3. GPU olarak **L40S 24 GB** seç (canlı kullanım için 48 GB).
4. Diske en az **100 GB** ver (modeller yaklaşık 30 GB yer kaplar).
5. Sunucuya bir **genel (public) IP** ver.
6. Güvenlik grubunda / güvenlik duvarında şu portları aç:

   | Port | Protokol | Ne için |
   |---|---|---|
   | 22 | TCP | Sunucuya bağlanmak |
   | 80, 443 | TCP | Test sayfası (HTTPS) |
   | 7881 | TCP | Ses (yedek yol) |
   | 50000–50100 | UDP | Ses |

> Panel adımları sağlayıcıya göre biraz farklı olabilir. Takılırsan ekran görüntüsünü at, birlikte bakalım.

### 3. Kurulum komutunu çalıştır

Panelde sunucunun **Console** (konsol) düğmesine tıkla, açılan siyah ekrana şu iki satırı yapıştır. `KULLANICI_ADIN` yerine kendi GitHub kullanıcı adını yaz:

```bash
git clone https://github.com/KULLANICI_ADIN/randevudent-ses.git && cd randevudent-ses
sudo bash kur.sh
```

Betik Docker'ı ve GPU desteğini kurar, anahtarları üretir, HTTPS sertifikasını alır ve her şeyi başlatır. Sonunda ekrana **test sayfası adresini ve şifresini** yazar; bunları not et.

> Betik "Sunucuyu yeniden başlat" derse: `sudo reboot` yaz, sunucu açılınca konsolda `cd randevudent-ses && sudo bash kur.sh` komutunu tekrar çalıştır.

### 4. Hazır olmasını bekle

İlk seferde modeller indiği için 10–25 dakika sürer. Durumu görmek için konsola şunu yaz:

```bash
sudo bash durum.sh
```

"Hazır" yazınca test sayfası adresini tarayıcıda aç.

### 5. Ayla ile konuş

1. Test sayfasında şifreyi gir, **Aramayı başlat**'a tıkla, mikrofon iznini ver.
2. Ayla seni selamlar; normal bir hasta gibi randevu almaya çalış.
3. Arama bitince **Alınan randevular** tablosunda kaydın düşüp düşmediğine bak.

### 6. Bitince sunucuyu kapat

GPU sunucu açık kaldığı her saat için ücret alınır. Test bitince paneldeki **Stop / Durdur** düğmesine bas. Tekrar açtığında servisler kendiliğinden başlar (birkaç dakika bekle, `durum.sh` ile kontrol et).

---

## Ne test edilmeli

Bu denemenin asıl sorusu: **Türkçe ses hastaya robot gibi geliyor mu, gecikme kabul edilebilir mi?**

- [ ] Ayla'nın sesi doğal mı? Vurgu ve tonlama rahatsız edici mi?
- [ ] Sen sustuktan sonra Ayla kaç saniyede cevap veriyor? (Hedef: 1,5 saniyenin altı)
- [ ] "Yarın", "cuma öğleden sonra" gibi ifadeleri doğru güne çeviriyor mu?
- [ ] Saatleri ve telefon numarasını doğru okuyor mu? ("09:30" → "dokuz buçuk")
- [ ] Telefon numaranı doğru anlıyor ve rakam rakam teyit ediyor mu?
- [ ] Sen konuşurken lafını kesersen susuyor mu?
- [ ] Şikâyetini anlatmaya başladığında nazikçe durduruyor mu? Kayıtta şikâyet bilgisi yok mu?
- [ ] "Dişim çok şişti, kanıyor" dediğinde acil hattına / 112'ye yönlendiriyor mu?
- [ ] Dolu bir saati istediğinde reddedip başka saat öneriyor mu?
- [ ] Randevu tabloya doğru bilgilerle düşüyor mu?

---

## Yazılımcı için teknik notlar

**Mimari.** `livekit` host ağında çalışır (UDP port aralığı için). `agent` LiveKit'e `host.docker.internal:7880` üzerinden bağlanır; STT, LLM ve TTS'e Docker ağında OpenAI uyumlu API ile erişir (`openai.STT/LLM/TTS(base_url=...)`). Caddy, `/rtc*` yolunu LiveKit'e, geri kalanını `web`'e yönlendirir ve sslip.io alan adı için Let's Encrypt sertifikası alır.

**GPU belleği.** `llm` önce başlar ve `LLM_GPU_ORANI` kadar bellek ayırır (24 GB'ta 0.55 ≈ 13 GB). `stt` (~3 GB) ve `tts` (~1–2 GB) `llm` sağlıklı olduktan sonra başlar. Bellek yetmezse `LLM_GPU_ORANI`'yı düşür veya `--max-model-len`'i küçült.

**Ayarlar** `.env` dosyasındadır (`kur.sh` üretir, `ayarlar.ornek.env` şablondur). Değiştirdikten sonra: `docker compose up -d`.

**Önemli dosyalar**

- `agent/agent.py` — Ayla'nın talimatları (sağlık verisi kuralları dahil), araçlar ve oturum ayarları. Qwen3'ün düşünme modu `chat_template_kwargs.enable_thinking=false` ile kapalı.
- `agent/takvim.py` — Deneme takvimi. Hekimler ve çalışma saatleri `veri/klinik.json`, randevular `veri/randevular.json`. **Canlıya geçerken bu sınıfı RandevuDent panelinin API'sine bağlayan bir sürümle değiştir** (`bos_saatler` ve `randevu_al` imzaları korunursa ajan değişmez).
- `tts/server.py` — `SesMotoru` sınıfı EMA-TTS'i sarar. Başka bir Türkçe modeli denemek için yalnızca bu sınıfı değiştir. LiveKit eklentisi `response_format="pcm"` ile 24 kHz / 16 bit / mono ham PCM bekler; sunucu 48 kHz çıktıyı yeniden örnekler.
- `stt/server.py` — faster-whisper; Türkçe sessizlik uydurmalarını ("Altyazı M.K." vb.) ayıklar.

**Faydalı komutlar**

```bash
docker compose logs -f agent      # Ayla'nın kayıtları
docker compose logs -f tts        # her cümlenin üretim süresi
docker compose restart agent      # talimat değişikliğinden sonra (önce: docker compose build agent)
```

**Gecikme ayarı.** İlk sesin gecikmesini en çok TTS belirler (`docker compose logs tts` her cümle için süre yazar). EMA-TTS akışlı (streaming) üretim yapmadığı için LiveKit metni cümlelere bölüp tek tek gönderir. Gecikme yüksekse: daha kısa cümleler (talimatta), daha küçük LLM, veya akışlı bir TTS'e geçiş.

**Bilinen sınırlamalar**

- Telefon (SIP) bağlantısı yok; sonraki aşamada LiveKit SIP + Netgsm/Verimor eklenecek.
- EMA-TTS tek sesli bir topluluk modeli; kalite ve kararlılığı test edilmeli.
- Deneme takvimi dosya tabanlıdır, tek sunucu içindir.
- Test sayfası tek bir şifreyle korunur; canlı kullanım için uygun değildir.

**Sorun giderme**

| Belirti | Olası sebep |
|---|---|
| Sayfa açılmıyor | 80/443 portları kapalı veya sertifika henüz alınmadı (`docker compose logs caddy`) |
| Bağlanıyor ama ses yok | UDP 50000–50100 veya TCP 7881 kapalı |
| Ayla katılmıyor | `docker compose logs agent`; STT/LLM/TTS henüz hazır değil olabilir |
| `llm` sürekli yeniden başlıyor | GPU belleği yetmiyor; `LLM_GPU_ORANI` veya modeli küçült |
| Mikrofon izni sorulmuyor | Sayfa HTTPS ile açılmamış |
