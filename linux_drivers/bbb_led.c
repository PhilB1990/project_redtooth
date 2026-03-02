/* Private Includes ---------------------------------------------------------*/

#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/gpio.h>
#include <linux/miscdevice.h>   /* misc_register, misc_deregister */
#include <linux/fs.h>           /* file_operations */
#include <linux/uaccess.h>      /* copy_from_user, copy_to_user */

/* Private defines ----------------------------------------------------------*/

#define BEAGLEBONE_USER_LED_COUNT   ( ( int )4 )

/* GPIO1_21..24 = USR0..USR3 (kernel 6.6 dynamic base +512, bank1 base=512) */
#define LED_GPIO_USR0               ( ( unsigned int )533 )
#define LED_GPIO_USR1               ( ( unsigned int )534 )
#define LED_GPIO_USR2               ( ( unsigned int )535 )
#define LED_GPIO_USR3               ( ( unsigned int )536 )

#define LED_TURN_OFF                ( ( char )'0' )
#define LED_TURN_ON                 ( ( char )'1' )

/* Private macros -----------------------------------------------------------*/

#define IS_POINTER_NULL( ptr )  ( NULL == ptr )

/* Private typedefs ---------------------------------------------------------*/

typedef struct
{
    unsigned int gpio;
    struct miscdevice misc;
} sBeagleBoneLEDDevice;

/* Private function declarations --------------------------------------------*/

static int LEDOpen( struct inode *inode, struct file *f );
static ssize_t LEDWrite( struct file *f, const char __user *buf, size_t len, loff_t *off );
static ssize_t LEDRead( struct file *f, char __user *buf, size_t len, loff_t *off );

/* Private variables --------------------------------------------------------*/

static const struct file_operations BbbLedFops =
{
    .owner = THIS_MODULE,
    .open  = LEDOpen,
    .write = LEDWrite,
    .read  = LEDRead,
};

/* All per-LED data in one place: GPIO, device name, and misc config */
static sBeagleBoneLEDDevice LEDDevices[ BEAGLEBONE_USER_LED_COUNT ] =
{
    { .gpio = LED_GPIO_USR0, .misc = { .minor = MISC_DYNAMIC_MINOR, .name = "bbb_led0", .fops = &BbbLedFops, .mode = 0666 } },
    { .gpio = LED_GPIO_USR1, .misc = { .minor = MISC_DYNAMIC_MINOR, .name = "bbb_led1", .fops = &BbbLedFops, .mode = 0666 } },
    { .gpio = LED_GPIO_USR2, .misc = { .minor = MISC_DYNAMIC_MINOR, .name = "bbb_led2", .fops = &BbbLedFops, .mode = 0666 } },
    { .gpio = LED_GPIO_USR3, .misc = { .minor = MISC_DYNAMIC_MINOR, .name = "bbb_led3", .fops = &BbbLedFops, .mode = 0666 } },
};

/* Private function definitions ---------------------------------------------*/

/* misc driver sets f->private_data = &miscdevice before calling open.
 * Replace it with a pointer to our sBeagleBoneLEDDevice so read/write know which GPIO. */
static int LEDOpen( struct inode *inode, struct file *f )
{
    f->private_data = container_of( f->private_data, sBeagleBoneLEDDevice, misc );
    return ( int )0;
}
/*---------------------------------------------------------------------------*/

static ssize_t LEDWrite( struct file *f, const char __user *buf, size_t len, loff_t *off )
{
    sBeagleBoneLEDDevice *dev = ( sBeagleBoneLEDDevice * )f->private_data;
    char val;

    if( ( size_t )1 > len )
    {
        return -EINVAL;
    }

    if( ( int )0 != copy_from_user( &val, buf, ( unsigned long )1 ) )
    {
        return -EFAULT;
    }

    gpio_set_value( dev->gpio, ( LED_TURN_ON == val ) ? ( int )1 : ( int )0 );

    return ( ssize_t )len;
}
/*---------------------------------------------------------------------------*/

static ssize_t LEDRead( struct file *f, char __user *buf, size_t len, loff_t *off )
{
    sBeagleBoneLEDDevice *dev = ( sBeagleBoneLEDDevice * )f->private_data;
    char val;

    if( ( loff_t )0 < *off )
    {
        return ( ssize_t )0;    /* EOF */
    }

    val = ( ( int )0 != gpio_get_value( dev->gpio ) ) ? LED_TURN_ON : LED_TURN_OFF;

    if( ( int )0 != copy_to_user( buf, &val, ( unsigned long )1 ) )
    {
        return -EFAULT;
    }

    *off = ( loff_t )1;

    return ( ssize_t )1;
}
/*---------------------------------------------------------------------------*/

static void LEDCleanup( int count )
{
    for( int i = ( int )0; i < count; i++ )
    {
        misc_deregister( &LEDDevices[ i ].misc );
        gpio_set_value( LEDDevices[ i ].gpio, ( int )0 );
        gpio_free( LEDDevices[ i ].gpio );
    }
}
/*---------------------------------------------------------------------------*/

static int __init LEDInit( void )
{
    int ret = ( int )0;

    pr_info( "BBB LED driver loaded (%d LEDs)\n", BEAGLEBONE_USER_LED_COUNT );

    for( int i = ( int )0; i < BEAGLEBONE_USER_LED_COUNT; i++ )
    {
        ret = gpio_request( LEDDevices[ i ].gpio, LEDDevices[ i ].misc.name );
        if( ( int )0 != ret )
        {
            pr_err( "BBB: gpio_request(%u) failed: %d\n", LEDDevices[ i ].gpio, ret );
            LEDCleanup( i );
            return ret;
        }

        gpio_direction_output( LEDDevices[ i ].gpio, ( int )0 );

        ret = misc_register( &LEDDevices[ i ].misc );
        if( ( int )0 != ret )
        {
            pr_err( "BBB: misc_register(%s) failed: %d\n", LEDDevices[ i ].misc.name, ret );
            gpio_free( LEDDevices[ i ].gpio );
            LEDCleanup( i );
            return ret;
        }
    }

    return ret;
}
/*---------------------------------------------------------------------------*/

static void __exit LEDExit( void )
{
    for( int i = ( int )0; i < BEAGLEBONE_USER_LED_COUNT; i++ )
    {
        misc_deregister( &LEDDevices[ i ].misc );
        gpio_set_value( LEDDevices[ i ].gpio, ( int )0 );
        gpio_free( LEDDevices[ i ].gpio );
    }

    pr_info( "BBB LED driver unloaded\n" );
}
/*---------------------------------------------------------------------------*/

/* Module informations ------------------------------------------------------*/

module_init( LEDInit );
module_exit( LEDExit );

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Your Name");
MODULE_DESCRIPTION("BeagleBone Black LED driver - /dev/bbb_led0..3 for USR0..3 LEDs");
