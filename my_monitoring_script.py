import os
import smtplib
import telegram
from selenium import webdriver
from PIL import Image
import io

# --- 配置区 ---
# 通过环境变量读取密钥，更安全
TELEGRAM_BOT_TOKEN = os.getenv('TELEGRAM_BOT_TOKEN')
TELEGRAM_CHAT_ID = os.getenv('TELEGRAM_CHAT_ID')

# 邮件配置 (如果需要)
SMTP_SERVER = os.getenv('SMTP_SERVER')
SMTP_PORT = int(os.getenv('SMTP_PORT', 587))
SMTP_USER = os.getenv('SMTP_USER')
SMTP_PASSWORD = os.getenv('SMTP_PASSWORD')
MAIL_FROM = os.getenv('MAIL_FROM')
MAIL_TO = os.getenv('MAIL_TO')

URL_TO_MONITOR = 'https://www.example.com'
SCREENSHOT_PATH = '/tmp/screenshot.png'
LAST_SCREENSHOT_PATH = '/tmp/last_screenshot.png' # 用于对比

def send_telegram_notification(message, image_path=None):
    if not TELEGRAM_BOT_TOKEN or not TELEGRAM_CHAT_ID:
        print("Telegram token 或 chat ID 未设置, 跳过发送。")
        return
    try:
        bot = telegram.Bot(token=TELEGRAM_BOT_TOKEN)
        if image_path:
            bot.send_photo(chat_id=TELEGRAM_CHAT_ID, photo=open(image_path, 'rb'), caption=message)
        else:
            bot.send_message(chat_id=TELEGRAM_CHAT_ID, text=message)
        print("Telegram 通知已发送。")
    except Exception as e:
        print(f"发送 Telegram 通知失败: {e}")

def main():
    print("开始执行网页视觉变化监控脚本...")
    
    # --- 1. 设置 Selenium ---
    options = webdriver.ChromeOptions()
    options.add_argument('--headless')
    options.add_argument('--no-sandbox')
    options.add_argument('--disable-dev-shm-usage')
    driver = webdriver.Chrome(options=options)
    
    try:
        # --- 2. 截取当前网页 ---
        driver.get(URL_TO_MONITOR)
        driver.save_screenshot(SCREENSHOT_PATH)
        print(f"已截取当前页面: {URL_TO_MONITOR}")

        # --- 3. 对比逻辑 (这里是一个简单的示例) ---
        # 如果旧的截图不存在，就当作第一次运行
        if not os.path.exists(LAST_SCREENSHOT_PATH):
            print("未发现旧的截图，将当前截图保存为基准。")
            os.rename(SCREENSHOT_PATH, LAST_SCREENSHOT_PATH)
            send_telegram_notification(f"已为 {URL_TO_MONITOR} 建立监控基准。")
            return

        # 对比新旧截图
        # 注意：这是一个像素级的精确对比，实际中您可能需要更复杂的算法
        # 比如计算图像哈希值、结构相似性指数(SSIM)等
        with Image.open(SCREENSHOT_PATH) as img1, Image.open(LAST_SCREENSHOT_PATH) as img2:
            if list(img1.getdata()) != list(img2.getdata()):
                print("检测到网页视觉变化！")
                message = f"警告: 监控的网页 {URL_TO_MONITOR} 发生了视觉变化！"
                send_telegram_notification(message, SCREENSHOT_PATH)
                # 更新基准截图
                os.rename(SCREENSHOT_PATH, LAST_SCREENSHOT_PATH)
            else:
                print("网页无变化。")

    except Exception as e:
        print(f"脚本执行出错: {e}")
        send_telegram_notification(f"监控脚本执行失败: {e}")
    finally:
        driver.quit()
        print("脚本执行完毕。")

if __name__ == '__main__':
    main()
