# aw app
PRODUCT_PACKAGES += \
    Update \
    VideoPlayer \

# for test
PRODUCT_PACKAGES += \
    DragonFire \
    DragonAging

# for off charging mode
PRODUCT_PACKAGES += \
    charger_res_images
	
# background manager
PRODUCT_PACKAGES += awbms

#display service
$(call inherit-product-if-exists, vendor/aw/public/package/display/display.mk)
