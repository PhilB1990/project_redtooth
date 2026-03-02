/* Private Includes ---------------------------------------------------------*/

#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/gpio.h>
#include <linux/miscdevice.h>   /* misc_register, misc_deregister */
#include <linux/fs.h>           /* file_operations */
#include <linux/uaccess.h>      /* copy_from_user, copy_to_user */

/* Private defines ----------------------------------------------------------*/

#define LED_GPIO                ( ( unsigned int )533 )    /* GPIO1_21 / D2 USR0 LED (kernel 6.6 dynamic base) */
#define LED_GPIO_LABEL          ( "bbb_led" )
#define LED_GPIO_INITIAL_VALUE  ( ( int )1 )

/* Private macros -----------------------------------------------------------*/

#define IS_POINTER_NULL( ptr )  ( ( NULL ) == ( ptr ) )

/* Private typedefs ---------------------------------------------------------*/

/* Private variables --------------------------------------------------------*/

/* Private function declarations --------------------------------------------*/

static int         GPIOInitOutput   ( unsigned gpio, const char *label, int initial_value );
static ssize_t     BbbLedWrite      ( struct file *f, const char __user *buf, size_t len, loff_t *off );
static ssize_t     BbbLedRead       ( struct file *f, char __user *buf, size_t len, loff_t *off );

/* Private variables --------------------------------------------------------*/

static const struct file_operations BbbLedFops =
{
    .owner = THIS_MODULE,
    .write = BbbLedWrite,
    .read  = BbbLedRead,
};

static struct miscdevice BbbLedMisc =
{
    .minor = MISC_DYNAMIC_MINOR,
    .name  = "bbb_led",           /* creates /dev/bbb_led */
    .fops  = &BbbLedFops,
    .mode  = 0666,                /* rw for all — CGI runs as root but explicit is cleaner */
};

/* Private function definitions ---------------------------------------------*/

static int GPIOInitOutput( unsigned gpio, const char *label, int initial_value )
{
    int ret = gpio_request( gpio, label );
    if( ( int )0 == ret )
    {
        gpio_direction_output( gpio, initial_value );
    }

    return ret;
}
/*---------------------------------------------------------------------------*/

/* Write '1' to turn LED on, '0' to turn it off. */
static ssize_t BbbLedWrite( struct file *f, const char __user *buf, size_t len, loff_t *off )
{
    char val;

    if( len < ( size_t )1 )
    {
        return -EINVAL;
    }

    if( ( int )0 != copy_from_user( &val, buf, ( unsigned long )1 ) )
    {
        return -EFAULT;
    }

    gpio_set_value( LED_GPIO, ( val == '1' ) ? ( int )1 : ( int )0 );

    return ( ssize_t )len;
}
/*---------------------------------------------------------------------------*/

/* Read returns '1' if LED is on, '0' if off. */
static ssize_t BbbLedRead( struct file *f, char __user *buf, size_t len, loff_t *off )
{
    char val;

    if( *off > ( loff_t )0 )
    {
        return ( ssize_t )0;    /* EOF */
    }

    val = ( gpio_get_value( LED_GPIO ) != ( int )0 ) ? '1' : '0';

    if( ( int )0 != copy_to_user( buf, &val, ( unsigned long )1 ) )
    {
        return -EFAULT;
    }

    *off = ( loff_t )1;

    return ( ssize_t )1;
}
/*---------------------------------------------------------------------------*/

static int __init led_init( void )
{
    int ret;

    pr_info( "BBB LED driver loaded\n" );

    ret = GPIOInitOutput( LED_GPIO, LED_GPIO_LABEL, LED_GPIO_INITIAL_VALUE );
    if( ( int )0 != ret )
    {
        pr_err( "BBB: GPIOInitOutput(%u) failed: %d\n", LED_GPIO, ret );
        return ret;
    }

    /* Register misc device so CGI can control LED via /dev/bbb_led.
     * Avoids need for CONFIG_GPIO_SYSFS in the kernel config. */
    ret = misc_register( &BbbLedMisc );
    if( ( int )0 != ret )
    {
        pr_err( "BBB: misc_register failed: %d\n", ret );
        gpio_free( LED_GPIO );
        return ret;
    }

    return ( int )0;
}
/*---------------------------------------------------------------------------*/

static void __exit led_exit( void )
{
    misc_deregister( &BbbLedMisc );
    gpio_set_value( LED_GPIO, 0 );
    gpio_free( LED_GPIO );

    pr_info( "BBB LED driver unloaded\n" );
}
/*---------------------------------------------------------------------------*/

/* Module informations ------------------------------------------------------*/

module_init( led_init );
module_exit( led_exit );

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Your Name");
MODULE_DESCRIPTION("BeagleBone Black LED driver - /dev/bbb_led char device for web control");
